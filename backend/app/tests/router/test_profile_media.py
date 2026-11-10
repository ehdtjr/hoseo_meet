import asyncio
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import AsyncMock, patch
from urllib.parse import urlsplit

from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.core.config import settings
from app.core.s3 import S3Manager
from app.core.security import get_custom_jwt_strategy, get_jwt_strategy
from app.main import app
from app.models import ProfileMedia, User
from app.service.email import get_email_service
from app.tests.conftest import BaseTest, TestSessionLocal, test_engine


class TestProfileMediaRoutes(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()
        self.tmp = TemporaryDirectory()
        self.root_patch = patch.object(settings, 'LOCAL_MEDIA_ROOT', Path(self.tmp.name))
        self.backend_patch = patch.object(settings, 'STORAGE_BACKEND', 'local')
        self.root_patch.start()
        self.backend_patch.start()
        self.storage = S3Manager()
        self.strategy = get_jwt_strategy()
        app.dependency_overrides[S3Manager] = lambda: self.storage
        app.dependency_overrides[get_email_service] = lambda: AsyncMock()
        app.dependency_overrides[get_custom_jwt_strategy] = lambda: self.strategy
        self.client = AsyncClient(
            transport=ASGITransport(app=app, raise_app_exceptions=False), base_url='http://test'
        )
        self.b_id, self.b_auth = await self.register('owner-b')
        self.b_url = await self.upload(self.b_auth, b'owner-b-image')
        self.b_key = (await self.record(self.b_id)).key

    async def asyncTearDown(self):
        await self.client.aclose()
        self.root_patch.stop()
        self.backend_patch.stop()
        self.tmp.cleanup()
        await super().asyncTearDown()

    async def register(self, name, **extra):
        response = await self.client.post('/api/v1/auth/register', json={
            'email': f'{name}@example.com', 'password': 'synthetic-password-18',
            'name': name, 'gender': 'male', **extra,
        })
        self.assertEqual(response.status_code, 201, response.text)
        self.assertNotIn('key', response.json())
        async with TestSessionLocal() as db:
            user = await db.get(User, response.json()['id'])
            user.is_verified = True
            await db.commit()
            await db.refresh(user)
            token = await self.strategy.write_token(user)
            return user.id, {'Authorization': f'Bearer {token}'}

    async def upload(self, auth, data=b'new-image'):
        response = await self.client.post('/api/v1/users/me/profile', headers=auth,
                                          files={'file': ('profile.webp', data, 'image/webp')})
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()['profile_url']

    async def record(self, user_id):
        async with TestSessionLocal() as db:
            return await db.get(ProfileMedia, user_id)

    async def assert_b_intact(self):
        self.assertEqual(self.storage.local.path(self.b_key).read_bytes(), b'owner-b-image')
        parsed = urlsplit(self.b_url)
        response = await self.client.get(parsed.path + '?' + parsed.query)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.content, b'owner-b-image')
        self.assertEqual((await self.record(self.b_id)).key, self.b_key)

    async def test_registration_cannot_claim_another_users_upload(self):
        a_id, a_auth = await self.register(
            'attacker-a', profile=self.b_url, key=self.b_key,
            uploader_id=self.b_id, storage_backend='local',
        )
        self.assertIsNone(await self.record(a_id))
        await self.upload(a_auth)
        self.assertEqual((await self.record(a_id)).uploader_id, a_id)
        await self.assert_b_intact()

    async def test_general_update_cannot_reassign_deletion_ownership(self):
        a_id, a_auth = await self.register('attacker-a')
        await self.upload(a_auth, b'old-a-image')
        a_key = (await self.record(a_id)).key
        response = await self.client.patch('/api/v1/auth/me', headers=a_auth, json={
            'id': a_id, 'profile': self.b_url, 'key': self.b_key,
            'uploader_id': self.b_id, 'storage_backend': 's3',
        })
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()['profile'], self.b_url)
        self.assertEqual((await self.record(a_id)).key, a_key)
        await self.upload(a_auth)
        self.assertFalse(self.storage.local.path(a_key).exists())
        await self.assert_b_intact()

    async def test_owned_replacement_and_cleanup_survive_new_storage_instance(self):
        self.storage = S3Manager()
        new_url = await self.upload(self.b_auth, b'replacement')
        self.assertNotEqual(new_url, self.b_url)
        self.assertFalse(self.storage.local.path(self.b_key).exists())
        new_key = (await self.record(self.b_id)).key
        self.assertEqual(self.storage.local.path(new_key).read_bytes(), b'replacement')

    async def test_admin_can_delete_user_with_profile_upload_record(self):
        admin_id, admin_auth = await self.register('synthetic-admin')
        await self.upload(admin_auth, b'admin-profile')
        admin_key = (await self.record(admin_id)).key

        response = await self.client.delete(f'/api/v1/auth/{self.b_id}', headers=admin_auth)
        self.assertEqual(response.status_code, 403)
        await self.assert_b_intact()

        async with TestSessionLocal() as db:
            admin = await db.get(User, admin_id)
            admin.is_superuser = True
            await db.commit()
        response = await self.client.delete(f'/api/v1/auth/{self.b_id}', headers=admin_auth)
        self.assertEqual(response.status_code, 204, response.text)
        self.assertIsNone(await self.record(self.b_id))
        async with TestSessionLocal() as db:
            self.assertIsNone(await db.get(User, self.b_id))
        self.assertEqual((await self.record(admin_id)).key, admin_key)
        self.assertEqual(self.storage.local.path(admin_key).read_bytes(), b'admin-profile')

    async def test_legacy_own_url_is_not_backfilled_as_ownership(self):
        a_id, a_auth = await self.register('legacy-a')
        from io import BytesIO
        from app.utils.s3 import generate_s3_key
        legacy_key = generate_s3_key(f'profile/user_{a_id}', 'profile.webp')
        legacy_url = await self.storage.local.upload_byte_file(BytesIO(b'legacy'), legacy_key)
        response = await self.client.patch('/api/v1/auth/me', headers=a_auth,
                                          json={'id': a_id, 'profile': legacy_url})
        self.assertEqual(response.status_code, 200, response.text)
        await self.upload(a_auth)
        self.assertEqual(self.storage.local.path(legacy_key).read_bytes(), b'legacy')

    async def test_database_failure_preserves_old_profile_and_cleans_new_file(self):
        with patch('sqlalchemy.ext.asyncio.AsyncSession.flush',
                   new=AsyncMock(side_effect=RuntimeError('synthetic database failure'))):
            response = await self.client.post('/api/v1/users/me/profile', headers=self.b_auth,
                                              files={'file': ('new.webp', b'new', 'image/webp')})
        self.assertEqual(response.status_code, 500)
        await self.assert_b_intact()
        self.assertEqual([p for p in Path(self.tmp.name).rglob('*') if p.is_file()],
                         [self.storage.local.path(self.b_key)])
        async with TestSessionLocal() as db:
            self.assertEqual(await db.scalar(select(User.profile).where(User.id == self.b_id)),
                             self.b_url)

    async def test_parallel_first_uploads_keep_only_the_current_owned_file(self):
        a_id, a_auth = await self.register('parallel-a')
        urls = await asyncio.gather(self.upload(a_auth, b'first'), self.upload(a_auth, b'second'))
        async with TestSessionLocal() as db:
            current_url = await db.scalar(select(User.profile).where(User.id == a_id))
        self.assertIn(current_url, urls)
        current_key = (await self.record(a_id)).key
        files = list((Path(self.tmp.name) / f'profile/user_{a_id}').iterdir())
        self.assertEqual(files, [self.storage.local.path(current_key)])
        self.assertIn(self.storage.local.path(current_key).read_bytes(), (b'first', b'second'))
        await self.assert_b_intact()

    async def test_cleanup_failure_does_not_undo_successful_replacement(self):
        with patch.object(self.storage, 'delete_profile_file',
                          new=AsyncMock(side_effect=OSError('synthetic storage failure'))):
            with self.assertLogs('app.service.profile_media', level='WARNING') as logs:
                new_url = await self.upload(self.b_auth, b'replacement')
        self.assertNotIn(self.b_url, ''.join(logs.output))
        new_key = (await self.record(self.b_id)).key
        self.assertNotEqual(new_key, self.b_key)
        self.assertEqual(self.storage.local.path(new_key).read_bytes(), b'replacement')
        async with TestSessionLocal() as db:
            self.assertEqual(await db.scalar(select(User.profile).where(User.id == self.b_id)),
                             new_url)

    async def test_old_backend_record_does_not_delete_same_key_in_current_backend(self):
        async with TestSessionLocal() as db:
            record = await db.get(ProfileMedia, self.b_id)
            record.storage_backend = 's3'
            await db.commit()
        await self.upload(self.b_auth)
        self.assertEqual(self.storage.local.path(self.b_key).read_bytes(), b'owner-b-image')
        self.assertEqual((await self.record(self.b_id)).storage_backend, 'local')

    async def test_existing_database_initializer_is_additive_and_repeatable(self):
        from app.scripts import init_profile_media

        # Simulate the existing schema, which has users but no upload registry.
        async with test_engine.begin() as conn:
            await conn.run_sync(ProfileMedia.__table__.drop)
        with patch.object(init_profile_media, 'engine', test_engine):
            await init_profile_media.main()
            await init_profile_media.main()
        self.assertIsNone(await self.record(self.b_id))
        async with TestSessionLocal() as db:
            self.assertEqual(await db.scalar(select(User.profile).where(User.id == self.b_id)),
                             self.b_url)
        self.assertEqual(self.storage.local.path(self.b_key).read_bytes(), b'owner-b-image')

    async def test_upload_requires_authentication_and_supported_content_type(self):
        response = await self.client.post('/api/v1/users/me/profile',
                                          files={'file': ('new.webp', b'new', 'image/webp')})
        self.assertEqual(response.status_code, 401)
        response = await self.client.post('/api/v1/users/me/profile', headers=self.b_auth,
                                          files={'file': ('new.txt', b'new', 'text/plain')})
        self.assertEqual(response.status_code, 400)
        await self.assert_b_intact()


    async def test_lost_commit_ack_keeps_committed_profile_file(self):
        from sqlalchemy.ext.asyncio import AsyncSession
        original = AsyncSession.commit

        async def commit_then_fail(db):
            await original(db)
            raise RuntimeError('lost acknowledgement')

        with patch.object(AsyncSession, 'commit', new=commit_then_fail):
            response = await self.client.post('/api/v1/users/me/profile', headers=self.b_auth,
                                              files={'file': ('new.webp', b'committed', 'image/webp')})
        self.assertEqual(response.status_code, 500)
        record = await self.record(self.b_id)
        self.assertNotEqual(record.key, self.b_key)
        self.assertEqual(self.storage.local.path(record.key).read_bytes(), b'committed')
