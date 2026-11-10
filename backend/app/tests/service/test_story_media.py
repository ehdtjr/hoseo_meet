import asyncio
from datetime import datetime, timedelta, timezone
from io import BytesIO
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import AsyncMock, patch

from fastapi import HTTPException, UploadFile
from sqlalchemy import JSON, event, literal, select, update

from app.core.config import settings
from app.core.s3 import S3Manager
from app.crud.story_post import StoryPostCRUD
from app.models import StoryMedia, StoryPost, Stream, Subscription, User
from app.schemas.story_post import StoryPostRequest
from app.service.story_media import collect_story_media, has_reference
from app.service.story_post import StoryPostService
from app.service.stream import get_stream_service, get_subscription_service
from app.tests.conftest import BaseTest, TestSessionLocal, test_engine

OVERLAY = {
    "text": "Story",
    "position": {"x": 0.5, "y": 0.5},
    "font_style": {"name": "sans", "size": 16, "color": "#ffffff"},
}


class TestStoryMedia(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()
        self.tmp = TemporaryDirectory()
        self.root_patch = patch.object(
            settings, "LOCAL_MEDIA_ROOT", Path(self.tmp.name)
        )
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)
        self.addCleanup(self.tmp.cleanup)
        self.storage = S3Manager()
        self.service = StoryPostService(
            StoryPostCRUD(),
            await get_stream_service(),
            await get_subscription_service(),
            self.storage,
        )
        users = [
            User(
                email=f"story-{i}@example.com",
                hashed_password="synthetic",
                name=f"Story {i}",
                gender="male",
                is_active=True,
                is_superuser=False,
                is_verified=True,
            )
            for i in range(2)
        ]
        self.db.add_all(users)
        await self.db.commit()
        for user in users:
            await self.db.refresh(user)
        self.owner, self.other = [user.id for user in users]

    async def upload(self, owner=None):
        url = await self.service.upload_image(
            self.db,
            owner or self.owner,
            UploadFile(
                BytesIO(b"synthetic-webp"),
                filename="story.webp",
                headers={"content-type": "image/webp"},
            ),
        )
        key = await self.db.scalar(
            select(StoryMedia.key).where(StoryMedia.upload_url == url)
        )
        await self.db.rollback()
        return url, key

    async def create(self, url, owner=None, db=None):
        return await self.service.create_story_post(
            db or self.db,
            owner or self.owner,
            StoryPostRequest(image_url=url, text_overlay=OVERLAY),
        )

    async def test_precommit_upload_failure_removes_only_new_file(self):
        _, keep = await self.upload(self.other)
        with patch.object(
            self.db, "flush", new=AsyncMock(side_effect=RuntimeError("flush"))
        ):
            with self.assertRaises(RuntimeError):
                await self.upload()
        self.assertEqual(
            [p for p in Path(self.tmp.name).rglob("*") if p.is_file()],
            [self.storage.local.path(keep)],
        )

    async def test_upload_lost_commit_ack_preserves_committed_file(self):
        original = self.db.commit

        async def commit_then_fail():
            await original()
            raise RuntimeError("lost acknowledgement")

        with patch.object(self.db, "commit", side_effect=commit_then_fail):
            with self.assertRaises(RuntimeError):
                await self.upload()
        record = await self.db.scalar(select(StoryMedia))
        self.assertTrue(self.storage.local.path(record.key).exists())

    async def test_create_failure_rolls_back_room_and_same_editor_url_can_retry(self):
        url, key = await self.upload()
        with patch.object(
            self.service.subscriber_service,
            "subscribe",
            new=AsyncMock(side_effect=RuntimeError("subscription")),
        ):
            with self.assertRaises(RuntimeError):
                await self.create(url)
        self.assertTrue(self.storage.local.path(key).exists())
        self.assertIsNone(await self.db.scalar(select(Stream.id)))
        self.assertIsNone(await self.db.scalar(select(StoryPost.id)))
        record = await self.db.get(StoryMedia, key)
        self.assertFalse(record.claimed)
        self.assertIsNone(record.deleted_at)
        self.assertEqual(
            await collect_story_media(self.db, self.storage, apply=True), []
        )
        # The unchanged editor resubmits the original URL and text overlay.
        retried = await self.create(url)
        self.assertEqual(retried.image_url, url)
        self.assertEqual(retried.text_overlay.text, OVERLAY["text"])
        self.assertEqual(len((await self.db.scalars(select(StoryPost))).all()), 1)

    async def test_read_url_is_not_upload_ownership_or_delete_authority(self):
        url, key = await self.upload(self.other)
        with self.assertRaises(HTTPException):
            await self.create(url)
        with self.assertRaises(HTTPException):
            await self.storage.delete_file(url)
        self.assertTrue(self.storage.local.path(key).exists())
        with self.assertRaises(HTTPException):
            await self.create("https://external.invalid/image.webp")

    async def test_url_change_read_manual_delete_and_chat_preservation(self):
        url, key = await self.upload()
        with patch.object(settings, "MEDIA_BASE_URL", "https://new.invalid/media"):
            post = await self.create(url)  # Older client still submits old upload URL.
            self.assertTrue(post.image_url.startswith("https://new.invalid/media/"))
            stored = await self.db.scalar(select(StoryPost.image_url))
            self.assertEqual(stored, key)
            detail = await self.service.get_detail_story_post(
                self.db, post.id, self.owner
            )
            listed = await self.service.list_story_post(self.db, self.owner)
            self.assertEqual(detail.image_url, post.image_url)
            from fastapi import FastAPI
            from httpx import ASGITransport, AsyncClient
            from app.api.routes.media import router as media_router

            app = FastAPI()
            app.include_router(media_router, prefix="/media")
            async with AsyncClient(
                transport=ASGITransport(app=app), base_url="https://new.invalid"
            ) as client:
                response = await client.get(post.image_url)
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.content, b"synthetic-webp")
            self.assertEqual(listed[0].image_url, post.image_url)
            await self.service.delete_story_post(self.db, post.id, self.owner)
        self.assertFalse(self.storage.local.path(key).exists())
        self.assertIsNotNone(await self.db.scalar(select(Stream.id)))
        self.assertIsNotNone(await self.db.scalar(select(Subscription.id)))

    async def test_other_users_old_url_reference_preserves_file_until_removed(self):
        url, key = await self.upload()
        post = await self.create(url)
        await self.db.execute(
            update(User).where(User.id == self.other).values(profile=url)
        )
        await self.db.commit()
        await self.service.delete_story_post(self.db, post.id, self.owner)
        self.assertTrue(self.storage.local.path(key).exists())
        await self.db.execute(
            update(User).where(User.id == self.other).values(profile=None)
        )
        await self.db.commit()
        await collect_story_media(self.db, self.storage, apply=True)
        self.assertFalse(self.storage.local.path(key).exists())

    async def test_expiration_task_removes_file_and_preserves_room(self):
        from app.celery import story_post_task

        url, key = await self.upload()
        post = await self.create(url)
        await self.db.execute(
            update(StoryPost)
            .where(StoryPost.id == post.id)
            .values(expires_at=datetime.now(timezone.utc) - timedelta(seconds=1))
        )
        await self.db.commit()
        await asyncio.to_thread(story_post_task.delete_expired_story_posts_task.run)
        self.assertFalse(self.storage.local.path(key).exists())
        self.assertIsNone(await self.db.scalar(select(StoryPost.id)))
        self.assertIsNotNone(await self.db.scalar(select(Stream.id)))
        self.assertIsNotNone(await self.db.scalar(select(Subscription.id)))

    async def test_dry_run_retry_backup_restore_and_unknown_file_protection(self):
        from app.scripts.collect_story_media import restore_local_file

        url, key = await self.upload()
        unknown = self.storage.local.path("legacy/unowned.webp")
        unknown.parent.mkdir(parents=True)
        unknown.write_bytes(b"legacy")
        # New uploads have a 24h claim grace period.
        self.assertEqual(await collect_story_media(self.db, self.storage), [])
        await self.db.execute(
            update(StoryMedia).values(
                created_at=datetime.now(timezone.utc) - timedelta(days=2)
            )
        )
        await self.db.commit()
        with TemporaryDirectory() as backup:
            backup = Path(backup)
            self.assertEqual(await collect_story_media(self.db, self.storage), [key])
            self.assertTrue(self.storage.local.path(key).exists())
            await collect_story_media(
                self.db, self.storage, apply=True, backup_dir=backup
            )
            self.assertEqual((backup / key).read_bytes(), b"synthetic-webp")
            self.assertEqual(
                await collect_story_media(
                    self.db, self.storage, apply=True, backup_dir=backup
                ),
                [],
            )
            restore_local_file(self.storage, backup, key, self.owner)
            self.assertEqual(
                self.storage.local.path(key).read_bytes(), b"synthetic-webp"
            )
            with self.assertRaises(FileExistsError):
                restore_local_file(self.storage, backup, key, self.owner)
        self.assertEqual(unknown.read_bytes(), b"legacy")

    async def test_storage_failure_is_retryable_after_manual_delete(self):
        url, key = await self.upload()
        post = await self.create(url)
        with patch.object(
            self.storage,
            "delete_story_file",
            new=AsyncMock(side_effect=OSError("storage")),
        ):
            await self.service.delete_story_post(self.db, post.id, self.owner)
        self.assertTrue(self.storage.local.path(key).exists())
        await collect_story_media(self.db, self.storage, apply=True)
        self.assertFalse(self.storage.local.path(key).exists())

    async def test_parallel_claims_only_create_one_story(self):
        url, key = await self.upload()

        async def claim():
            async with TestSessionLocal() as db:
                try:
                    return await self.create(url, db=db)
                except HTTPException as exc:
                    return exc.status_code

        results = await asyncio.gather(claim(), claim())
        self.assertEqual(
            sum(isinstance(result, int) and result == 403 for result in results), 1
        )
        self.assertEqual(len((await self.db.scalars(select(StoryPost))).all()), 1)
        self.assertTrue(self.storage.local.path(key).exists())

    async def test_http_upload_create_list_delete_contract(self):
        from fastapi import FastAPI
        from httpx import ASGITransport, AsyncClient
        from app.api.routes.story_post import router
        from app.core.db import get_async_session
        from app.core.security import current_active_user
        from app.service.story_post import get_story_post_service

        app = FastAPI()
        app.include_router(router)
        app.dependency_overrides[current_active_user] = lambda: User(id=self.owner)
        app.dependency_overrides[get_story_post_service] = lambda: self.service

        async def db_dependency():
            yield self.db

        app.dependency_overrides[get_async_session] = db_dependency
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.post(
                "/upload_image", files={"file": ("story.webp", b"image", "image/webp")}
            )
            self.assertEqual(response.status_code, 200, response.text)
            uploaded = response.json()["url"]
            response = await client.post(
                "/create", json={"image_url": uploaded, "text_overlay": OVERLAY}
            )
            self.assertEqual(response.status_code, 200, response.text)
            story_id = response.json()["id"]
            self.assertEqual(response.json()["image_url"], uploaded)
            response = await client.get("/list")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()[0]["id"], story_id)
            response = await client.delete(f"/delete/{story_id}")
            self.assertEqual(response.status_code, 204)

    async def test_story_commit_lost_ack_keeps_committed_story_and_file(self):
        url, key = await self.upload()
        original = self.db.commit

        async def commit_then_fail():
            await original()
            raise RuntimeError("lost acknowledgement")

        with patch.object(self.db, "commit", side_effect=commit_then_fail):
            with self.assertRaises(RuntimeError):
                await self.create(url)
        self.assertTrue(self.storage.local.path(key).exists())
        self.assertIsNotNone(await self.db.scalar(select(StoryPost.id)))
        self.assertEqual(
            await collect_story_media(self.db, self.storage, apply=True), []
        )

    async def test_encoded_old_url_reference_is_preserved(self):
        url, key = await self.upload()
        post = await self.create(url)
        encoded_url = url.replace("story_post/", "story_post%2F").replace(
            f"/{self.owner}/", f"{self.owner}%2F"
        )
        await self.db.execute(
            update(User).where(User.id == self.other).values(profile=encoded_url)
        )
        await self.db.commit()
        await self.service.delete_story_post(self.db, post.id, self.owner)
        self.assertTrue(self.storage.local.path(key).exists())

    async def test_inflight_reference_write_is_rechecked_after_table_lock(self):
        from sqlalchemy import delete

        url, key = await self.upload()
        post = await self.create(url)
        await self.db.execute(delete(StoryPost).where(StoryPost.id == post.id))
        await self.db.commit()
        async with TestSessionLocal() as writer, TestSessionLocal() as collector:
            await writer.execute(
                update(User).where(User.id == self.other).values(profile=url)
            )
            task = asyncio.create_task(
                collect_story_media(collector, self.storage, apply=True)
            )
            await asyncio.sleep(0.05)
            await writer.commit()
            self.assertEqual(await asyncio.wait_for(task, timeout=10), [])
        self.assertTrue(self.storage.local.path(key).exists())

    async def test_encoded_uuid_reference_remains_readable_after_collection(self):
        from fastapi import FastAPI
        from httpx import ASGITransport, AsyncClient
        from app.api.routes.media import router as media_router
        from sqlalchemy import delete

        url, key = await self.upload()
        post = await self.create(url)
        await self.db.execute(delete(StoryPost).where(StoryPost.id == post.id))
        await self.db.commit()
        identifier = key.rsplit("/", 1)[-1].split("_", 1)[0]
        representations = [
            f"%{ord(identifier[0]):02x}" + identifier[1:],
            "".join(f"%{ord(char):02x}" for char in identifier),
            "".join(
                f"%{ord(char):02x}" if i % 2 else char
                for i, char in enumerate(identifier)
            ),
        ]
        media_app = FastAPI()
        media_app.include_router(media_router, prefix="/api/v1/media")
        async with AsyncClient(
            transport=ASGITransport(app=media_app), base_url="http://test"
        ) as client:
            for representation in representations:
                encoded_url = url.replace(identifier, representation)
                await self.db.execute(
                    update(User)
                    .where(User.id == self.other)
                    .values(profile=encoded_url)
                )
                await self.db.commit()
                self.assertEqual((await client.get(encoded_url)).status_code, 200)
                self.assertEqual(
                    await collect_story_media(self.db, self.storage, apply=True), []
                )
                self.assertEqual((await client.get(encoded_url)).status_code, 200)
                self.assertTrue(self.storage.local.path(key).exists())
            await self.db.execute(
                update(User).where(User.id == self.other).values(profile=None)
            )
            await self.db.commit()
            self.assertEqual(
                await collect_story_media(self.db, self.storage, apply=True), [key]
            )
            self.assertEqual((await client.get(url)).status_code, 404)

    async def test_encoded_uuid_in_json_history_preserves_reference(self):
        identifier = "abcdef0123456789abcdef0123456789"
        encoded = "".join(f"%{ord(char):02x}" for char in identifier)
        for suffix, expected in ((encoded, True), ("other-image", False)):
            history = select(
                literal(
                    {"images": [f"https://old.invalid/{suffix}_story.webp"]}, type_=JSON
                ).label("payload")
            ).subquery()
            self.assertEqual(
                await has_reference(
                    self.db, {history: [history.c.payload]}, identifier
                ),
                expected,
            )

    async def test_failed_draft_is_collected_after_24_hour_grace(self):
        url, key = await self.upload()
        with patch.object(
            self.service.stream_service,
            "create_stream",
            new=AsyncMock(side_effect=RuntimeError("transient")),
        ):
            with self.assertRaises(RuntimeError):
                await self.create(url)
        await self.db.execute(
            update(StoryMedia)
            .where(StoryMedia.key == key)
            .values(created_at=datetime.now(timezone.utc) - timedelta(days=2))
        )
        await self.db.commit()
        self.assertEqual(
            await collect_story_media(self.db, self.storage, apply=True), [key]
        )
        self.assertFalse(self.storage.local.path(key).exists())

    async def test_published_uploads_do_not_search_message_or_history_tables(self):
        for _ in range(3):
            url, _ = await self.upload()
            await self.create(url)
        await self.upload()  # A recent unclaimed draft also needs no text scan.
        statements = []

        def capture(conn, cursor, statement, parameters, context, executemany):
            statements.append(statement)

        event.listen(test_engine.sync_engine, "before_cursor_execute", capture)
        try:
            self.assertEqual(await collect_story_media(self.db, self.storage), [])
            self.assertEqual(
                await collect_story_media(self.db, self.storage, apply=True), []
            )
        finally:
            event.remove(test_engine.sync_engine, "before_cursor_execute", capture)
        self.assertEqual(len(statements), 2)
        self.assertFalse(
            any(
                "LIKE" in statement or " ~ " in statement or "FOR UPDATE" in statement
                for statement in statements
            )
        )


def test_cli_and_celery_register_mappers_without_importing_api():
    import subprocess
    import sys

    for module in ("app.scripts.collect_story_media", "app.celery.story_post_task"):
        result = subprocess.run(
            [
                sys.executable,
                "-c",
                f"import {module}; from sqlalchemy.orm import configure_mappers; configure_mappers()",
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        assert result.returncode == 0, result.stderr
