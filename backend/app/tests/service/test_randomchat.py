import asyncio
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

from sqlalchemy import func, select, text, update
from sqlalchemy.exc import SQLAlchemyError

from app.domains.randomchat.service import RandomChatService
from app.models import Recipient, Stream, Subscription, User
from app.models.randomchat import RandomChatQueue
from app.tests.conftest import BaseTest, TestSessionLocal


class TestRandomChatService(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()
        self.service = RandomChatService()
        self.users = await self.create_users(6)
        self.user_ids = [user.id for user in self.users]

    async def create_users(self, count: int) -> list[User]:
        users = [
            User(
                email=f"random-{index}@example.com",
                hashed_password="hashedpassword",
                name=f"Random User {index}",
                gender="male",
                is_active=True,
                is_superuser=False,
                is_verified=True,
            )
            for index in range(count)
        ]
        self.db.add_all(users)
        await self.db.commit()
        for user in users:
            await self.db.refresh(user)
        return users

    async def call_in_new_session(self, method_name: str, user_id: int):
        async with TestSessionLocal() as session:
            return await getattr(self.service, method_name)(session, user_id)

    async def random_stream_count(self) -> int:
        return await self.db.scalar(
            select(func.count())
            .select_from(Stream)
            .where(Stream.type == "random")
        )

    async def test_two_users_create_one_room_and_two_subscriptions(self):
        first_id, second_id = self.user_ids[:2]

        first_result = await self.service.join(self.db, first_id)
        second_result = await self.service.join(self.db, second_id)
        first_status = await self.service.status(self.db, first_id)

        self.assertEqual(first_result.status, "waiting")
        self.assertEqual(second_result.status, "matched")
        self.assertIsNotNone(second_result.stream_id)
        self.assertEqual(first_status.status, "matched")
        self.assertEqual(first_status.stream_id, second_result.stream_id)

        stream = await self.db.get(Stream, second_result.stream_id)
        self.assertEqual(stream.type, "random")
        self.assertEqual(stream.creator_id, first_id)
        recipient = await self.db.scalar(
            select(Recipient).where(Recipient.type_id == stream.id)
        )
        subscriptions = (
            await self.db.scalars(
                select(Subscription)
                .where(Subscription.recipient_id == recipient.id)
                .order_by(Subscription.user_id)
            )
        ).all()
        self.assertEqual(
            [subscription.user_id for subscription in subscriptions],
            sorted([first_id, second_id]),
        )
        self.assertTrue(all(subscription.active for subscription in subscriptions))

    async def test_duplicate_join_is_idempotent_before_and_after_match(self):
        first_id, second_id = self.user_ids[:2]

        initial = await self.service.join(self.db, first_id)
        duplicate_waiting = await self.service.join(self.db, first_id)
        matched = await self.service.join(self.db, second_id)
        # Simulate a committed response that the client never received.
        duplicate_matched = await self.call_in_new_session("join", second_id)

        self.assertEqual(initial.status, "waiting")
        self.assertEqual(duplicate_waiting.status, "waiting")
        self.assertEqual(matched.status, "matched")
        self.assertEqual(duplicate_matched.status, "matched")
        self.assertEqual(duplicate_matched.stream_id, matched.stream_id)
        self.assertEqual(await self.random_stream_count(), 1)
        queue_count = await self.db.scalar(
            select(func.count()).select_from(RandomChatQueue)
        )
        self.assertEqual(queue_count, 2)

    async def test_concurrent_joins_match_each_user_only_once(self):
        user_ids = self.user_ids

        results = await asyncio.gather(
            *(self.call_in_new_session("join", user_id) for user_id in user_ids)
        )

        self.assertTrue(all(result.status in {"waiting", "matched"} for result in results))
        self.assertEqual(await self.random_stream_count(), 3)
        subscriptions = (
            await self.db.execute(
                select(Subscription.user_id, func.count(Subscription.id))
                .join(Recipient, Recipient.id == Subscription.recipient_id)
                .join(Stream, Stream.id == Recipient.type_id)
                .where(Stream.type == "random", Subscription.active.is_(True))
                .group_by(Subscription.user_id)
            )
        ).all()
        self.assertEqual(
            dict(subscriptions), {user_id: 1 for user_id in user_ids}
        )

    async def test_same_user_concurrent_join_does_not_self_match(self):
        user_id = self.user_ids[0]

        results = await asyncio.gather(
            self.call_in_new_session("join", user_id),
            self.call_in_new_session("join", user_id),
        )

        self.assertEqual([result.status for result in results], ["waiting", "waiting"])
        queue_count = await self.db.scalar(
            select(func.count()).select_from(RandomChatQueue)
        )
        self.assertEqual(queue_count, 1)
        self.assertEqual(await self.random_stream_count(), 0)

    async def test_duplicate_and_heartbeat_preserve_fifo_position(self):
        first_id, second_id, third_id = self.user_ids[:3]
        await self.service.join(self.db, first_id)
        first_entry = await self.db.get(RandomChatQueue, first_id)
        original_queued_at = first_entry.queued_at

        await self.service.join(self.db, first_id)
        await self.service.status(self.db, first_id)
        first_entry = await self.db.get(
            RandomChatQueue, first_id, populate_existing=True
        )
        self.assertEqual(first_entry.queued_at, original_queued_at)

        self.db.add(
            RandomChatQueue(
                user_id=second_id,
                queued_at=original_queued_at + timedelta(seconds=1),
                expires_at=datetime.now(timezone.utc) + timedelta(minutes=5),
            )
        )
        await self.db.commit()

        matched = await self.service.join(self.db, third_id)

        self.assertEqual(matched.status, "matched")
        stream = await self.db.get(Stream, matched.stream_id)
        self.assertEqual(stream.creator_id, first_id)
        second_status = await self.service.status(self.db, second_id)
        self.assertEqual(second_status.status, "waiting")

    async def test_leave_cancels_waiting_but_never_hides_a_won_match(self):
        first_id, second_id = self.user_ids[:2]
        await self.service.join(self.db, first_id)

        join_result, leave_result = await asyncio.gather(
            self.call_in_new_session("join", second_id),
            self.call_in_new_session("leave", first_id),
        )
        first_status = await self.service.status(self.db, first_id)
        second_status = await self.service.status(self.db, second_id)

        if join_result.status == "matched":
            self.assertEqual(leave_result.status, "matched")
            self.assertEqual(first_status.status, "matched")
            self.assertEqual(second_status.status, "matched")
            self.assertEqual(first_status.stream_id, second_status.stream_id)
        else:
            self.assertEqual(join_result.status, "waiting")
            self.assertEqual(leave_result.status, "idle")
            self.assertEqual(first_status.status, "idle")
            self.assertEqual(second_status.status, "waiting")

    async def test_match_failure_rolls_back_new_user_and_preserves_peer(self):
        first_id, second_id = self.user_ids[:2]
        await self.service.join(self.db, first_id)

        async with TestSessionLocal() as failed_session:
            original_flush = failed_session.flush
            flush_count = 0

            async def fail_after_rows_are_flushed(*args, **kwargs):
                nonlocal flush_count
                flush_count += 1
                await original_flush(*args, **kwargs)
                if flush_count == 4:
                    # A real PostgreSQL error aborts the transaction after all
                    # partial rows exist, unlike a Python-only injected error.
                    await failed_session.execute(text("SELECT 1 / 0"))

            with patch.object(failed_session, "flush", fail_after_rows_are_flushed):
                with self.assertRaises(SQLAlchemyError):
                    await self.service.join(failed_session, second_id)

        queue_rows = (
            await self.db.scalars(
                select(RandomChatQueue).order_by(RandomChatQueue.user_id)
            )
        ).all()
        self.assertEqual([row.user_id for row in queue_rows], [first_id])
        self.assertIsNone(queue_rows[0].stream_id)
        self.assertEqual(await self.random_stream_count(), 0)
        self.assertEqual(
            await self.db.scalar(select(func.count()).select_from(Recipient)), 0
        )
        self.assertEqual(
            await self.db.scalar(select(func.count()).select_from(Subscription)), 0
        )

        retry = await self.call_in_new_session("join", second_id)
        self.assertEqual(retry.status, "matched")
        self.assertEqual(await self.random_stream_count(), 1)

    async def test_expired_waiter_is_removed_and_cannot_be_matched(self):
        first_id, second_id = self.user_ids[:2]
        await self.service.join(self.db, first_id)
        await self.db.execute(
            update(RandomChatQueue)
            .where(RandomChatQueue.user_id == first_id)
            .values(expires_at=datetime.now(timezone.utc) - timedelta(seconds=1))
        )
        await self.db.commit()

        expired_status = await self.service.status(self.db, first_id)
        second_result = await self.service.join(self.db, second_id)

        self.assertEqual(expired_status.status, "idle")
        self.assertEqual(second_result.status, "waiting")
        self.assertEqual(await self.random_stream_count(), 0)

    async def test_deactivated_waiter_is_removed_before_matching(self):
        first_id, second_id = self.user_ids[:2]
        await self.service.join(self.db, first_id)
        await self.db.execute(
            update(User).where(User.id == first_id).values(is_active=False)
        )
        await self.db.commit()

        second_result = await self.service.join(self.db, second_id)

        self.assertEqual(second_result.status, "waiting")
        queue_ids = (
            await self.db.scalars(select(RandomChatQueue.user_id))
        ).all()
        self.assertEqual(queue_ids, [second_id])
        self.assertEqual(await self.random_stream_count(), 0)

    async def test_successful_cancel_before_next_join_prevents_match(self):
        first_id, second_id = self.user_ids[:2]
        await self.service.join(self.db, first_id)

        leave_result = await self.service.leave(self.db, first_id)
        second_result = await self.service.join(self.db, second_id)

        self.assertEqual(leave_result.status, "idle")
        self.assertEqual(second_result.status, "waiting")
        self.assertEqual(await self.random_stream_count(), 0)

    async def test_request_cancellation_rolls_back_partial_match(self):
        first_id, second_id = self.user_ids[:2]
        await self.service.join(self.db, first_id)

        async with TestSessionLocal() as cancelled_session:
            original_flush = cancelled_session.flush
            flush_count = 0

            async def cancel_after_rows_are_flushed(*args, **kwargs):
                nonlocal flush_count
                flush_count += 1
                await original_flush(*args, **kwargs)
                if flush_count == 4:
                    raise asyncio.CancelledError()

            with patch.object(
                cancelled_session, "flush", cancel_after_rows_are_flushed
            ):
                with self.assertRaises(asyncio.CancelledError):
                    await self.service.join(cancelled_session, second_id)

        queue_rows = (
            await self.db.scalars(select(RandomChatQueue))
        ).all()
        self.assertEqual([row.user_id for row in queue_rows], [first_id])
        self.assertIsNone(queue_rows[0].stream_id)
        self.assertEqual(await self.random_stream_count(), 0)
        self.assertEqual(
            await self.db.scalar(select(func.count()).select_from(Recipient)), 0
        )
        self.assertEqual(
            await self.db.scalar(select(func.count()).select_from(Subscription)), 0
        )

    async def test_inactive_subscription_allows_user_to_queue_again(self):
        first_id, second_id = self.user_ids[:2]
        await self.service.join(self.db, first_id)
        matched = await self.service.join(self.db, second_id)
        stream = await self.db.get(Stream, matched.stream_id)
        subscription = await self.db.scalar(
            select(Subscription).where(
                Subscription.user_id == first_id,
                Subscription.recipient_id == stream.recipient_id,
            )
        )
        subscription.active = False
        await self.db.commit()

        rejoined = await self.service.join(self.db, first_id)

        self.assertEqual(rejoined.status, "waiting")
        self.assertIsNone(rejoined.stream_id)
        second_status = await self.service.status(self.db, second_id)
        self.assertEqual(second_status.status, "matched")
        self.assertEqual(second_status.stream_id, matched.stream_id)
