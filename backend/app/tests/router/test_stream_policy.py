"""HTTP policy and real PostgreSQL transaction regression tests for issue #19."""

import asyncio
import json
from pathlib import Path
from tempfile import TemporaryDirectory
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from fastapi import Header
from httpx import ASGITransport, AsyncClient
from sqlalchemy import func, select, text, update

from app.core.config import settings
from app.core.s3 import S3Manager, get_s3_manager
from app.core.db import get_async_session
from app.core.security import current_active_user
from app.main import app
from app.models import Recipient, Stream, Subscription, User
from app.models.meet_post import MeetPost
from app.models.story_post import StoryPost
from app.schemas.recipient import RecipientType
from app.service.event.events import get_event_dispatcher
from app.service.stream import SubscriberService, get_subscription_service
from app.tests.conftest import BaseTest, TestSessionLocal


class TestStreamPolicy(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()
        users = [User(email=f"policy{i}@example.com", name=f"policy{i}",
                      hashed_password="unused", gender="male", is_active=True)
                 for i in range(4)]
        self.db.add_all(users)
        await self.db.flush()
        self.user_ids = [user.id for user in users]
        await self.db.commit()

        async def current_user(x_test_user: int = Header()):
            return SimpleNamespace(id=x_test_user)

        async def request_db():
            # Match the production session; message inserts read values after commit.
            async with TestSessionLocal(expire_on_commit=False) as db:
                yield db

        self.tmp = TemporaryDirectory()
        self.root_patch = patch.object(settings, "LOCAL_MEDIA_ROOT", Path(self.tmp.name))
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)
        self.addCleanup(self.tmp.cleanup)
        storage = S3Manager()
        app.dependency_overrides[get_s3_manager] = lambda: storage
        self.dispatcher = AsyncMock()
        app.dependency_overrides[get_async_session] = request_db
        app.dependency_overrides[current_active_user] = current_user
        app.dependency_overrides[get_event_dispatcher] = lambda: self.dispatcher
        self.client = AsyncClient(transport=ASGITransport(app=app), base_url="http://test")

    async def asyncTearDown(self):
        await self.client.aclose()
        await super().asyncTearDown()

    async def room(self, kind="meet", capacity=2, backing=True):
        stream = Stream(name="Policy room", type=kind, creator_id=self.user_ids[0])
        self.db.add(stream)
        await self.db.flush()
        recipient = Recipient(type=RecipientType.STREAM.value, type_id=stream.id)
        self.db.add(recipient)
        await self.db.flush()
        stream.recipient_id = recipient.id
        post = None
        if backing and kind in {"meet", "delivery", "taxi", "carpool"}:
            post = MeetPost(author_id=self.user_ids[0], stream_id=stream.id,
                            title="Policy", type=kind, content="Synthetic", max_people=capacity)
        elif backing and kind == "story":
            post = StoryPost(author_id=self.user_ids[0], stream_id=stream.id,
                             image_url="/synthetic.webp", text_overlay={
                                 "text": "Synthetic", "position": {"x": 0.5, "y": 0.5},
                                 "font_style": {"name": "sans", "size": 12, "color": "#000000"},
                             })
        if post:
            self.db.add(post)
        await self.db.flush()
        result = SimpleNamespace(id=stream.id, recipient_id=recipient.id,
                                 post_id=post.id if post else None)
        await self.db.commit()
        return result

    async def membership(self, room, user_index=0, active=True, eligible=True):
        self.db.add(Subscription(user_id=self.user_ids[user_index],
                                 recipient_id=room.recipient_id, active=active,
                                 is_user_active=eligible))
        await self.db.commit()

    async def join(self, room, user_index=1, route="generic"):
        path = "/api/v1/users/me/subscriptions"
        if route == "meet":
            path = f"/api/v1/meet_post/subscribe/{room.post_id}"
        return await self.client.post(path, json={"stream_id": room.id},
                                      headers={"x-test-user": str(self.user_ids[user_index])})

    async def location(self, room, user_index=1):
        return await self.client.post(
            f"/api/v1/messages/send/stream/location/{room.id}",
            json={"lat": 36.0, "lng": 127.0},
            headers={"x-test-user": str(self.user_ids[user_index])})

    async def count(self, room):
        async with TestSessionLocal() as db:
            return await db.scalar(select(func.count()).select_from(Subscription).where(
                Subscription.recipient_id == room.recipient_id,
                Subscription.active.is_(True)))

    async def test_all_meeting_types_enforce_capacity_on_both_routes(self):
        for kind in ("meet", "delivery", "taxi", "carpool"):
            with self.subTest(kind=kind):
                room = await self.room(kind, capacity=1)
                await self.membership(room)
                for route in ("generic", "meet"):
                    response = await self.join(room, route=route)
                    self.assertEqual(response.status_code, 400, response.text)
                self.assertEqual(await self.count(room), 1)

    async def test_rejoin_full_room_is_rejected(self):
        room = await self.room(capacity=1)
        await self.membership(room)
        await self.membership(room, 1, active=False)
        for route in ("generic", "meet"):
            response = await self.join(room, route=route)
            self.assertEqual(response.status_code, 400, response.text)
        self.assertEqual(await self.count(room), 1)

    async def test_join_leave_rejoin_message_and_location(self):
        room = await self.room()
        await self.membership(room)
        headers = {"x-test-user": str(self.user_ids[1])}
        self.assertEqual((await self.join(room, route="meet")).status_code, 200)
        self.assertEqual((await self.join(room)).status_code, 400)
        response = await self.client.request("DELETE", "/api/v1/users/me/subscriptions",
                                            json={"stream_id": room.id}, headers=headers)
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual((await self.location(room)).status_code, 403)
        self.dispatcher.dispatch.assert_not_awaited()
        self.assertEqual((await self.join(room)).status_code, 200)
        self.assertEqual((await self.location(room)).status_code, 200)
        event = self.dispatcher.dispatch.call_args.kwargs["event_data"]
        self.assertEqual(json.loads(event.data)["user_id"], self.user_ids[1])
        self.assertEqual(set(self.dispatcher.dispatch.call_args.kwargs["user_ids"]),
                         set(self.user_ids[:2]))
        response = await self.client.post(f"/api/v1/messages/send/stream/{room.id}",
                                         data={"message_content": "Synthetic message"},
                                         headers=headers)
        self.assertEqual(response.status_code, 200, response.text)
        # Location remains immediate; messages commit a durable recipient outbox.
        self.assertEqual(self.dispatcher.dispatch.await_count, 1)
        self.assertEqual(response.json()["storage_status"], "saved")
        self.assertEqual(response.json()["delivery_status"], "pending")
        from app.models.message_outbox import MessageOutbox
        deliveries = (await self.db.scalars(select(MessageOutbox).where(
            MessageOutbox.message_id == response.json()["message_id"]))).all()
        self.assertEqual({row.user_id for row in deliveries}, set(self.user_ids[:2]))
        self.assertTrue(all(row.completed_at is None for row in deliveries))
        self.assertEqual(await self.count(room), 2)

    async def test_nonmember_location_never_dispatches(self):
        room = await self.room()
        await self.membership(room)
        self.assertEqual((await self.location(room)).status_code, 403)
        self.assertEqual((await self.location(SimpleNamespace(id=999999))).status_code, 403)
        self.dispatcher.dispatch.assert_not_awaited()

    async def test_ineligible_subscription_cannot_rejoin_or_send_location(self):
        for active in (False, True):
            with self.subTest(active=active):
                room = await self.room()
                await self.membership(room, 1, active=active, eligible=False)
                for route in ("generic", "meet"):
                    self.assertEqual((await self.join(room, route=route)).status_code, 403)
                self.assertEqual((await self.location(room)).status_code, 403)
        self.dispatcher.dispatch.assert_not_awaited()

    async def test_inactive_account_cannot_join_or_send_location(self):
        room = await self.room()
        await self.membership(room, 1)
        await self.db.execute(update(User).where(User.id.in_(self.user_ids[1:3]))
                              .values(is_active=False))
        await self.db.commit()
        self.assertEqual((await self.join(room, 2)).status_code, 403)
        self.assertEqual((await self.join(room)).status_code, 403)
        self.assertEqual((await self.location(room)).status_code, 403)
        self.dispatcher.dispatch.assert_not_awaited()

    async def test_missing_or_unsupported_rooms_reject_first_join_and_rejoin(self):
        self.assertEqual((await self.join(SimpleNamespace(id=999999))).status_code, 404)
        for kind in ("meet", "story", "random", "unknown"):
            with self.subTest(kind=kind):
                room = await self.room(kind, backing=False)
                self.assertEqual((await self.join(room)).status_code, 403)
                await self.membership(room, 1, active=False)
                self.assertEqual((await self.join(room)).status_code, 403)
                self.assertEqual(await self.count(room), 0)

    async def test_recipient_type_collision_does_not_grant_membership(self):
        room = await self.room()
        wrong = Recipient(type=RecipientType.USER.value, type_id=room.id)
        self.db.add(wrong)
        await self.db.flush()
        wrong_id = wrong.id
        self.db.add(Subscription(user_id=self.user_ids[1], recipient_id=wrong_id,
                                 active=True, is_user_active=True))
        await self.db.commit()
        self.assertEqual((await self.location(room)).status_code, 403)
        self.assertEqual((await self.join(room)).status_code, 200)
        self.assertEqual(await self.count(room), 1)
        await self.db.execute(update(Stream).where(Stream.id == room.id)
                              .values(recipient_id=wrong_id))
        await self.db.commit()
        self.assertEqual((await self.join(room, 2)).status_code, 404)
        self.assertEqual((await self.location(room)).status_code, 403)
        self.dispatcher.dispatch.assert_not_awaited()

    async def test_story_join_rejoin_and_expiration(self):
        room = await self.room("story")
        self.assertEqual((await self.join(room)).status_code, 200)
        await self.db.execute(update(Subscription).where(
            Subscription.recipient_id == room.recipient_id).values(active=False))
        await self.db.commit()
        self.assertEqual((await self.join(room)).status_code, 200)
        await self.db.execute(update(StoryPost).where(StoryPost.id == room.post_id)
                              .values(expires_at=datetime.now(timezone.utc) - timedelta(seconds=1)))
        await self.db.execute(update(Subscription).where(
            Subscription.recipient_id == room.recipient_id).values(active=False))
        await self.db.commit()
        self.assertEqual((await self.join(room)).status_code, 403)
        self.assertEqual((await self.join(room, 2)).status_code, 403)
        response = await self.client.post(
            f"/api/v1/story_post/subscribe/{room.post_id}",
            headers={"x-test-user": str(self.user_ids[2])})
        self.assertEqual(response.status_code, 403, response.text)

    async def test_failed_write_releases_room_lock_and_does_not_consume_seat(self):
        room = await self.room(capacity=1)
        service = await get_subscription_service()
        service.subscription_crud.create = AsyncMock(side_effect=RuntimeError("write failed"))
        with self.assertRaisesRegex(RuntimeError, "write failed"):
            await service.subscribe(self.db, self.user_ids[1], room.id)
        self.assertFalse(self.db.in_transaction())
        self.assertEqual(await self.count(room), 0)
        response = await asyncio.wait_for(self.join(room, 2), timeout=5)
        self.assertEqual(response.status_code, 200, response.text)

    async def test_meet_creation_rejects_nonmeeting_types(self):
        for kind in ("story", "random"):
            response = await self.client.post("/api/v1/meet_post/create", json={
                "title": "Synthetic", "type": kind, "content": "Synthetic", "max_people": 2,
            }, headers={"x-test-user": str(self.user_ids[0])})
            self.assertEqual(response.status_code, 422, response.text)

    async def upload_story_image(self):
        response = await self.client.post(
            "/api/v1/story_post/upload_image",
            files={"file": ("synthetic.webp", b"synthetic-image", "image/webp")},
            headers={"x-test-user": str(self.user_ids[0])},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["url"]

    async def test_creator_joins_meeting_and_story(self):
        headers = {"x-test-user": str(self.user_ids[0])}
        response = await self.client.post("/api/v1/meet_post/create", json={
            "title": "Synthetic", "type": "meet", "content": "Synthetic", "max_people": 1,
        }, headers=headers)
        self.assertEqual(response.status_code, 200, response.text)
        room = SimpleNamespace(id=response.json()["stream_id"])
        self.assertEqual((await self.join(room)).status_code, 400)
        response = await self.client.post("/api/v1/story_post/create", json={
            "image_url": await self.upload_story_image(), "text_overlay": {
                "text": "Synthetic", "position": {"x": 0.5, "y": 0.5},
                "font_style": {"name": "sans", "size": 12, "color": "#000000"},
            },
        }, headers=headers)
        self.assertEqual(response.status_code, 200, response.text)
        self.assertTrue(response.json()["is_subscribed"])
        async with TestSessionLocal() as db:
            stream_id = await db.scalar(select(StoryPost.stream_id).where(
                StoryPost.id == response.json()["id"]))
        self.assertEqual((await self.join(SimpleNamespace(id=stream_id))).status_code, 200)

    async def create_post(self, kind):
        payload = {"title": "Synthetic", "type": "meet", "content": "Synthetic", "max_people": 1}
        if kind == "story":
            payload = {"image_url": await self.upload_story_image(), "text_overlay": {
                "text": "Synthetic", "position": {"x": 0.5, "y": 0.5},
                "font_style": {"name": "sans", "size": 12, "color": "#000000"},
            }}
        return await self.client.post(f"/api/v1/{kind}_post/create", json=payload,
                                      headers={"x-test-user": str(self.user_ids[0])})

    async def creation_visibility(self, kind):
        pending_room = asyncio.get_running_loop().create_future()
        resume_creator = asyncio.Event()
        original_subscribe = SubscriberService.subscribe

        async def paused_subscribe(service, db, user_id, stream_id, *, commit=True):
            if user_id == self.user_ids[0]:
                # The creator has flushed the room and post, but has not joined.
                pending_room.set_result(stream_id)
                await resume_creator.wait()
            return await original_subscribe(service, db, user_id, stream_id, commit=commit)

        with patch.object(SubscriberService, "subscribe", new=paused_subscribe):
            creation = asyncio.create_task(self.create_post(kind))
            try:
                stream_id = await asyncio.wait_for(pending_room, timeout=5)
                async with TestSessionLocal() as observer:
                    self.assertIsNone(await observer.scalar(select(Stream.id).where(Stream.id == stream_id)))
                    self.assertIsNone(await observer.scalar(select(Recipient.id).where(
                        Recipient.type == RecipientType.STREAM.value, Recipient.type_id == stream_id)))
                    post_type = MeetPost if kind == "meet" else StoryPost
                    self.assertIsNone(await observer.scalar(select(post_type.id).where(
                        post_type.stream_id == stream_id)))
                # A simultaneous external request cannot claim the creator's seat.
                room = SimpleNamespace(id=stream_id)
                response = await asyncio.wait_for(self.join(room), timeout=5)
                self.assertEqual(response.status_code, 404, response.text)
                resume_creator.set()
                response = await asyncio.wait_for(creation, timeout=5)
                self.assertEqual(response.status_code, 200, response.text)
                async with TestSessionLocal() as observer:
                    members = (await observer.execute(select(Subscription.user_id)
                        .join(Recipient, Recipient.id == Subscription.recipient_id)
                        .where(Recipient.type == RecipientType.STREAM.value,
                               Recipient.type_id == stream_id))).scalars().all()
                    self.assertEqual(members, [self.user_ids[0]])
                self.assertEqual((await self.join(room)).status_code, 400 if kind == "meet" else 200)
            finally:
                resume_creator.set()
                if not creation.done():
                    creation.cancel()
                await asyncio.gather(creation, return_exceptions=True)

    async def test_meeting_not_visible_until_creator_has_reserved_seat(self):
        await self.creation_visibility("meet")

    async def test_story_not_visible_until_creator_has_joined(self):
        await self.creation_visibility("story")

    async def creation_rollback(self, kind):
        original_subscribe = SubscriberService.subscribe

        async def fail_after_subscription(service, db, user_id, stream_id, *, commit=True):
            await original_subscribe(service, db, user_id, stream_id, commit=commit)
            raise RuntimeError("Synthetic failure after creator subscription")

        with patch.object(SubscriberService, "subscribe", new=fail_after_subscription):
            with self.assertRaisesRegex(RuntimeError, "Synthetic failure"):
                await self.create_post(kind)
        # A failure even after the subscription write rolls back the whole aggregate.
        async with TestSessionLocal() as observer:
            for model in (MeetPost, StoryPost, Subscription, Stream, Recipient):
                self.assertEqual(await observer.scalar(select(func.count()).select_from(model)), 0)

    async def test_meeting_creation_failure_rolls_back_all_rows(self):
        await self.creation_rollback("meet")

    async def test_story_creation_failure_rolls_back_all_rows(self):
        await self.creation_rollback("story")

    async def test_legacy_meet_types_remain_readable_and_deletable(self):
        post_ids = []
        for kind in ("story", "random"):
            room = await self.room(kind, backing=False)
            post = MeetPost(author_id=self.user_ids[0], stream_id=room.id,
                            title="Legacy", type=kind, content="Legacy", max_people=2)
            self.db.add(post)
            await self.db.flush()
            post_ids.append(post.id)
            await self.db.commit()
        headers = {"x-test-user": str(self.user_ids[0])}
        response = await self.client.get("/api/v1/meet_post/search", headers=headers)
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual({post["type"] for post in response.json()}, {"story", "random"})
        for post_id in post_ids:
            response = await self.client.get(f"/api/v1/meet_post/detail/{post_id}", headers=headers)
            self.assertEqual(response.status_code, 200, response.text)
            response = await self.client.delete(f"/api/v1/meet_post/delete/{post_id}", headers=headers)
            self.assertEqual(response.status_code, 200, response.text)
        response = await self.client.get("/api/v1/meet_post/search", headers=headers)
        self.assertEqual(response.json(), [])

    async def race(self, room, same_user=False):
        # Hold the room row until BOTH independent HTTP sessions wait on it.
        # This proves real overlap and locking rather than merely using gather.
        await self.db.execute(select(Stream.id).where(Stream.id == room.id).with_for_update())
        tasks = [asyncio.create_task(self.join(room, 1, "generic")),
                 asyncio.create_task(self.join(room, 1 if same_user else 2, "meet"))]
        try:
            async with TestSessionLocal() as monitor:
                for _ in range(200):
                    waiting = await monitor.scalar(text("""
                        SELECT count(*) FROM pg_stat_activity
                        WHERE datname = current_database() AND wait_event_type = 'Lock'
                          AND query LIKE '%FROM streams%'
                    """))
                    await monitor.rollback()  # refresh pg_stat_activity snapshot
                    if waiting >= 2:
                        break
                    await asyncio.sleep(0.01)
                else:
                    self.fail("Both HTTP joins must wait on the PostgreSQL room lock")
            await self.db.rollback()
            responses = await asyncio.wait_for(asyncio.gather(*tasks), timeout=10)
            self.assertEqual(sorted(r.status_code for r in responses), [200, 400],
                             [r.text for r in responses])
            self.assertEqual(await self.count(room), 2)
        finally:
            await self.db.rollback()
            for task in tasks:
                if not task.done():
                    task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)

    async def test_concurrent_last_seat_across_both_apis(self):
        room = await self.room()
        await self.membership(room)
        await self.race(room)

    async def test_concurrent_rejoin_and_new_join_last_seat(self):
        room = await self.room()
        await self.membership(room)
        await self.membership(room, 1, active=False)
        await self.race(room)

    async def test_concurrent_duplicate_join(self):
        room = await self.room(capacity=3)
        await self.membership(room)
        await self.race(room, same_user=True)
