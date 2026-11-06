"""Integration tests use only the dedicated PostgreSQL/Redis from BaseTest."""
import asyncio
from contextlib import suppress
import sys
import os
from functools import partial
from unittest.mock import AsyncMock, patch

from fastapi import HTTPException
from httpx import ASGITransport, AsyncClient
from sqlalchemy import func, select, text, update

from app.core.config import settings
from app.core.security import current_active_user
from app.crud.message import MessageCRUD, UserMessageCRUD
from app.crud.recipient import RecipientCRUD
from app.crud.stream import SubscriptionCRUD
from app.main import app
from app.models import Message, Recipient, Stream, Subscription, User
from app.models.message import UserMessage
from app.models.message_outbox import MessageOutbox
from app.models.user import UserFCMToken
from app.schemas.recipient import RecipientType
from app.scripts.migrate_message_outbox import migrate
from app.service.message import MessageSendService
from app.service.message_outbox import MessageOutboxWorker
from app.service.message_fcm import send_fcm_isolated
from app.tests.conftest import BaseTest, TestSessionLocal, test_engine


class TestMessageOutbox(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()
        users = [User(email=f"outbox{i}@example.com", hashed_password="synthetic",
                      name=f"User {i}", gender="male", is_active=True,
                      is_verified=True, is_superuser=False) for i in range(2)]
        self.db.add_all(users)
        await self.db.flush()
        self.user_ids = [u.id for u in users]
        self.sender_id = self.user_ids[0]
        stream = Stream(name="Outbox test", creator_id=self.sender_id, type="배달")
        self.db.add(stream)
        await self.db.flush()
        self.stream_id = stream.id
        recipient = Recipient(type=RecipientType.STREAM.value, type_id=stream.id)
        self.db.add(recipient)
        await self.db.flush()
        self.recipient_id = recipient.id
        stream.recipient_id = recipient.id
        self.db.add_all([Subscription(user_id=u, recipient_id=recipient.id,
                                      is_user_active=True, active=True) for u in self.user_ids])
        await self.db.commit()
        self.service = MessageSendService(MessageCRUD(), UserMessageCRUD(), RecipientCRUD(),
                                          SubscriptionCRUD())
        self.worker = MessageOutboxWorker(TestSessionLocal)
        for user_id in self.user_ids:
            await self.redis_client.set(f"active_stream:{user_id}", self.stream_id)

    async def send(self, key="logical-message", content="synthetic private message", sender=None):
        async with TestSessionLocal() as db:
            return await self.service.send_message_stream(
                db, sender or self.sender_id, self.stream_id, content, key)

    async def counts(self):
        async with TestSessionLocal() as db:
            return [await db.scalar(select(func.count()).select_from(model))
                    for model in (Message, UserMessage, MessageOutbox)]

    async def ready(self):
        async with TestSessionLocal() as db:
            await db.execute(update(MessageOutbox).values(available_at=func.now()))
            await db.commit()

    async def rows(self):
        async with TestSessionLocal() as db:
            return list((await db.scalars(select(MessageOutbox).order_by(MessageOutbox.id))).all())

    async def test_recipient_failure_rolls_back_message_and_partial_recipients(self):
        async def fail_after_first(db, data):
            await UserMessageCRUD().bulk_create(db, data[:1])
            raise RuntimeError("injected recipient failure")

        with patch.object(self.service.user_message_crud, "bulk_create", side_effect=fail_after_first):
            with self.assertRaises(RuntimeError):
                await self.send()
        self.assertEqual(await self.counts(), [0, 0, 0])
        await self.send()
        self.assertEqual(await self.counts(), [1, 2, 2])

    async def test_outbox_insert_failure_rolls_back_all_storage(self):
        from sqlalchemy.ext.asyncio import AsyncSession
        with patch.object(AsyncSession, "add_all", side_effect=RuntimeError("outbox unavailable")):
            with self.assertRaises(RuntimeError):
                await self.send()
        self.assertEqual(await self.counts(), [0, 0, 0])

    async def test_concurrent_retries_save_one_logical_message(self):
        results = await asyncio.gather(*(self.send() for _ in range(8)))
        self.assertEqual(len({r.message_id for r in results}), 1)
        self.assertEqual(sum(not r.duplicate for r in results), 1)
        self.assertEqual(await self.counts(), [1, 2, 2])
        self.assertEqual((await self.send()).delivery_status, "pending")
        await asyncio.gather(self.worker.process_one(), self.worker.process_one())
        self.assertEqual((await self.send()).delivery_status, "completed")
        for user in self.user_ids:
            self.assertEqual(await self.redis_client.xlen(f"queue:{user}"), 1)

    async def test_key_conflict_and_sender_scope(self):
        await self.send()
        with self.assertRaises(HTTPException) as caught:
            await self.send(content="changed")
        self.assertEqual(caught.exception.status_code, 409)
        await self.send(sender=self.user_ids[1])
        self.assertEqual(await self.counts(), [2, 4, 4])

    async def test_legacy_requests_get_distinct_generated_keys(self):
        first, second = await self.send(key=None), await self.send(key=None)
        self.assertNotEqual(first.client_message_id, second.client_message_id)
        self.assertEqual(await self.counts(), [2, 4, 4])

    async def test_redis_failure_is_pending_then_recovers(self):
        await self.send()
        with patch.object(self.redis_client, "eval", side_effect=ConnectionError("private payload")):
            with self.assertLogs("app.service.message_outbox", level="WARNING") as logs:
                await self.worker.process_one()
        self.assertNotIn("private payload", " ".join(logs.output))
        row = (await self.rows())[0]
        self.assertEqual(row.attempts, 1)
        self.assertIsNone(row.completed_at)
        self.assertGreater(row.available_at, row.created_at)
        self.assertTrue((await self.send()).duplicate)
        await self.ready()
        while await self.worker.process_one():
            pass
        self.assertEqual(await self.counts(), [1, 2, 2])
        for user in self.user_ids:
            self.assertEqual(await self.redis_client.xlen(f"queue:{user}"), 1)

    async def test_fcm_provider_failure_retries_without_repeating_completed_recipient(self):
        receiver = self.user_ids[1]
        await self.redis_client.delete(f"active_stream:{receiver}")
        self.db.add(UserFCMToken(user_id=receiver, fcm_token="synthetic-token"))
        await self.db.commit()
        await self.send()
        with patch.object(settings, "FCM_ENABLED", True):
            await self.worker.process_one()  # sender's Redis delivery completes
            await self.worker.process_one()  # persist receiver's FCM route
            with patch("app.service.message_outbox.send_fcm_isolated", side_effect=partial(
                send_fcm_isolated, command=self.fcm_command("failure")
            )):
                await self.worker.process_one("fcm")
            self.assertEqual((await self.rows())[1].last_error, "FCMDeliveryError")
            self.assertTrue((await self.send()).duplicate)
            await self.ready()
            with patch("app.service.message_outbox.send_fcm_isolated", side_effect=partial(
                send_fcm_isolated, command=self.fcm_command("success")
            )):
                await MessageOutboxWorker(TestSessionLocal).process_one("fcm")
        self.assertEqual((await self.rows())[1].outcome, "fcm_accepted")
        self.assertEqual(await self.redis_client.xlen(f"queue:{self.sender_id}"), 1)
        self.assertEqual(await self.counts(), [1, 2, 2])

    async def test_worker_cancellation_keeps_event_pending(self):
        await self.send()
        delivery = AsyncMock()
        delivery.deliver.side_effect = asyncio.CancelledError()
        with self.assertRaises(asyncio.CancelledError):
            await MessageOutboxWorker(TestSessionLocal, delivery).process_one()
        self.assertIsNone((await self.rows())[0].completed_at)
        await self.worker.process_one()
        self.assertIsNotNone((await self.rows())[0].completed_at)

    @staticmethod
    def fcm_command(mode):
        # Run the real subprocess entrypoint with a synthetic provider, without
        # credentials or network access. Both token fanout and ack checks run.
        script = r"""
import sys, runpy
import app.service.message_fcm as fcm
mode = sys.argv.pop()
class Provider:
    def __init__(self, **kwargs): pass
    def notify(self, **kwargs):
        assert kwargs['fcm_token'].startswith('synthetic')
        assert kwargs['data_payload']['message_id']
        return {'name': 'projects/synthetic/messages/ok'} if mode == 'success' else {}
fcm.FCMNotification = Provider
runpy.run_module('app.scripts.deliver_message_fcm', run_name='__main__')
"""
        return [sys.executable, "-c", script, str(os.getpid()), mode]

    async def test_fcm_unacknowledged_response_stays_pending(self):
        receiver = self.user_ids[1]
        await self.redis_client.delete(f"active_stream:{receiver}")
        self.db.add_all([UserFCMToken(user_id=receiver, fcm_token=f"synthetic-{i}")
                         for i in range(2)])
        await self.db.commit()
        await self.send()
        with patch.object(settings, "FCM_ENABLED", True):
            await self.worker.process_one()
            await self.worker.process_one()
            with patch("app.service.message_outbox.send_fcm_isolated", side_effect=partial(
                send_fcm_isolated, command=self.fcm_command("unacknowledged")
            )):
                await self.worker.process_one("fcm")
            self.assertIsNone((await self.rows())[1].completed_at)
            await self.ready()
            with patch("app.service.message_outbox.send_fcm_isolated", side_effect=partial(
                send_fcm_isolated, command=self.fcm_command("success")
            )):
                await self.worker.process_one("fcm")
        self.assertEqual((await self.rows())[1].outcome, "fcm_accepted")

    async def test_disabled_fcm_and_missing_token_have_explicit_outcomes(self):
        for user in self.user_ids:
            await self.redis_client.delete(f"active_stream:{user}")
        await self.send()
        with patch.object(settings, "FCM_ENABLED", False):
            await self.worker.process_one()
        with patch.object(settings, "FCM_ENABLED", True):
            await self.worker.process_one()
            await self.worker.process_one("fcm")
        self.assertEqual([r.outcome for r in await self.rows()], ["fcm_disabled", "no_fcm_token"])
        self.assertEqual((await self.send()).delivery_status, "completed")

    async def test_api_lifespan_drains_pending_events(self):
        from app.main import lifespan
        await self.send()
        with patch("app.main.MessageOutboxWorker", return_value=self.worker), patch(
            "app.main.instrumentator.expose"
        ), patch("app.main.redis_client.close_connection", new_callable=AsyncMock):
            async with lifespan(app):
                for _ in range(100):
                    if all(r.completed_at for r in await self.rows()):
                        break
                    await asyncio.sleep(0.05)
                else:
                    self.fail("Lifespan worker did not drain pending deliveries")
        self.assertEqual((await self.send()).delivery_status, "completed")

    async def test_blocked_fcm_does_not_delay_later_redis_deliveries(self):
        receiver = self.user_ids[1]
        await self.redis_client.delete(f"active_stream:{receiver}")
        self.db.add(UserFCMToken(user_id=receiver, fcm_token="synthetic-token"))
        await self.db.commit()
        await self.send()
        started, release = asyncio.Event(), asyncio.Event()

        async def blocked_fcm(*args):
            started.set()
            await release.wait()

        with patch.object(settings, "FCM_ENABLED", True), patch(
            "app.service.message_outbox.send_fcm_isolated", side_effect=blocked_fcm
        ):
            task = asyncio.create_task(self.worker.run())
            try:
                await asyncio.wait_for(started.wait(), timeout=5)
                await self.redis_client.set(f"active_stream:{receiver}", self.stream_id)
                await self.send(key="later-message")
                for _ in range(100):
                    if await self.redis_client.xlen(f"queue:{receiver}") == 1:
                        break
                    await asyncio.sleep(0.05)
                else:
                    self.fail("FCM blocked the independent Redis routing worker")
                self.assertFalse(release.is_set())
                self.assertIsNone((await self.rows())[1].completed_at)
                self.assertEqual(await self.redis_client.xlen(f"queue:{self.sender_id}"), 2)
            finally:
                release.set()
                task.cancel()
                with suppress(asyncio.CancelledError):
                    await task

    async def test_fcm_timeout_reaps_sender_before_row_can_retry(self):
        receiver = self.user_ids[1]
        await self.redis_client.delete(f"active_stream:{receiver}")
        self.db.add(UserFCMToken(user_id=receiver, fcm_token="synthetic-token"))
        await self.db.commit()
        await self.send()
        processes = []
        create_process = asyncio.create_subprocess_exec

        async def capture_process(*args, **kwargs):
            if processes:
                self.assertIsNotNone(processes[-1].returncode)
            process = await create_process(*args, **kwargs)
            processes.append(process)
            return process

        command = [sys.executable, "-c", "import sys,time; sys.stdin.read(); time.sleep(60)"]
        with patch.object(settings, "FCM_ENABLED", True), patch(
            "app.service.message_fcm.asyncio.create_subprocess_exec", side_effect=capture_process
        ):
            await self.worker.process_one()
            await self.worker.process_one()
            with patch("app.service.message_outbox.send_fcm_isolated", side_effect=partial(
                send_fcm_isolated, command=command, timeout=0.1
            )):
                await self.worker.process_one("fcm")
            self.assertIsNotNone(processes[0].returncode)
            self.assertNotEqual(processes[0].returncode, 0)
            row = (await self.rows())[1]
            self.assertEqual(row.last_error, "TimeoutError")
            self.assertIsNone(row.completed_at)
            await self.ready()
            with patch("app.service.message_outbox.send_fcm_isolated", side_effect=partial(
                send_fcm_isolated, command=self.fcm_command("success")
            )):
                await self.worker.process_one("fcm")
            self.assertEqual(processes[1].returncode, 0)
        self.assertEqual((await self.rows())[1].outcome, "fcm_accepted")

    async def test_migration_adds_channel_to_pre_review_outbox(self):
        await self.send()
        async with test_engine.begin() as conn:
            await conn.execute(text("ALTER TABLE message_outbox DROP COLUMN channel"))
            await migrate(conn)
            await migrate(conn)
        self.assertEqual([row.channel for row in await self.rows()], ["route", "route"])
        await self.worker.process_one()
        self.assertEqual((await self.rows())[0].outcome, "redis_accepted")

    async def test_process_crash_after_redis_publish_recovers_without_duplicate_event(self):
        await self.send()
        # The first child exits after Redis accepts, before DB commit. A second
        # independent process uses only durable state to finish both deliveries.
        script = '''
import asyncio, os, sys
from app.core.redis import redis_client
from app.service.message_outbox import MessageOutboxDelivery, MessageOutboxWorker
from app.tests.conftest import TestSessionLocal, TEST_REDIS_URL
from aioredis import Redis
class CrashDelivery(MessageOutboxDelivery):
    async def deliver(self, db, row):
        await super().deliver(db, row)
        os._exit(73)
async def main():
    redis_client.redis = Redis.from_url(TEST_REDIS_URL, decode_responses=True)
    worker = MessageOutboxWorker(TestSessionLocal, CrashDelivery() if sys.argv[1] == "crash" else None)
    while await worker.process_one():
        pass
    await redis_client.redis.close()
asyncio.run(main())
'''
        for mode, expected in (("crash", 73), ("recover", 0)):
            proc = await asyncio.create_subprocess_exec(
                sys.executable, "-c", script, mode,
                stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
            try:
                stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=40)
            except BaseException:
                proc.kill()
                await proc.wait()
                raise
            self.assertEqual(proc.returncode, expected, stderr.decode())
        self.assertTrue(all(row.completed_at for row in await self.rows()))
        for user in self.user_ids:
            self.assertEqual(await self.redis_client.xlen(f"queue:{user}"), 1)
        self.assertEqual(await self.counts(), [1, 2, 2])

    async def test_existing_schema_migration_is_repeatable_and_preserves_messages(self):
        await self.send()
        async with test_engine.begin() as conn:
            await conn.execute(text("DROP TABLE message_outbox"))
            await conn.execute(text("ALTER TABLE message DROP COLUMN client_message_id"))
            await migrate(conn)
            await migrate(conn)
        self.assertEqual(await self.counts(), [1, 2, 0])
        await self.send()
        self.assertEqual(await self.counts(), [2, 4, 2])

    async def test_http_header_retry_conflict_and_validation(self):
        from types import SimpleNamespace
        app.dependency_overrides[current_active_user] = lambda: SimpleNamespace(id=self.sender_id)
        url = f"/api/v1/messages/send/stream/{self.stream_id}"
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            async def post(content="synthetic", key="http-id"):
                return await client.post(url, data={"message_content": content},
                                         headers={"X-Client-Message-ID": key})
            first, second = await post(), await post()
            self.assertEqual(first.status_code, 200)
            self.assertEqual(first.json()["storage_status"], "saved")
            self.assertEqual(first.json()["delivery_status"], "pending")
            self.assertEqual(first.json()["message_id"], second.json()["message_id"])
            self.assertTrue(second.json()["duplicate"])
            self.assertEqual((await post(content="changed")).status_code, 409)
            self.assertEqual((await post(key="x" * 129)).status_code, 422)
            self.assertEqual((await post(key=" ")).status_code, 422)
        self.assertEqual(await self.counts(), [1, 2, 2])
