from io import BytesIO
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import IsolatedAsyncioTestCase
from unittest.mock import patch
from urllib.parse import urlsplit

from fastapi import FastAPI, HTTPException
from httpx import ASGITransport, AsyncClient

from app.api.routes.media import router
from app.core.config import settings
from app.core.local_storage import LocalStorage
from app.utils.s3 import generate_s3_key


class TestLocalStorage(IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.tmp = TemporaryDirectory()
        self.root_patch = patch.object(settings, 'LOCAL_MEDIA_ROOT', Path(self.tmp.name))
        self.root_patch.start()
        self.storage = LocalStorage()
        self.app = FastAPI()
        self.app.include_router(router, prefix='/api/v1/media')

    async def asyncTearDown(self):
        self.root_patch.stop()
        self.tmp.cleanup()

    async def test_upload_read_restart_delete(self):
        url = await self.storage.upload_byte_file(BytesIO(b'image-data'), 'profiles/random.png')
        parsed = urlsplit(url)
        async with AsyncClient(transport=ASGITransport(app=self.app), base_url='http://test') as client:
            response = await client.get(parsed.path + '?' + parsed.query)
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.content, b'image-data')
            self.assertEqual(response.headers['cache-control'], 'private, no-store')
            self.assertEqual((await client.get(parsed.path)).status_code, 403)
            self.assertEqual((await client.get(parsed.path + '?signature=forged')).status_code, 403)
            self.assertEqual((await client.get('/api/v1/media/profiles/other.png?' + parsed.query)).status_code, 403)
            # New storage instance represents restart with the same volume/key.
            await LocalStorage().delete_file(url)
            self.assertEqual((await client.get(parsed.path + '?' + parsed.query)).status_code, 404)

    async def test_reject_traversal_symlink_and_foreign_delete(self):
        for key in ('../secret', '/etc/passwd', 'a/../../secret', 'a\\secret', 'a/./secret'):
            with self.assertRaises(HTTPException):
                await self.storage.upload_byte_file(BytesIO(b'data'), key)
        (Path(self.tmp.name) / 'escape').symlink_to('/tmp', target_is_directory=True)
        with self.assertRaises(HTTPException):
            self.storage.path('escape/secret')
        with self.assertRaises(HTTPException):
            await self.storage.delete_file('https://foreign.invalid/profiles/image.png')
        url = await self.storage.upload_byte_file(BytesIO(b'data'), 'profiles/image.png')
        with self.assertRaises(FileExistsError):
            await self.storage.upload_byte_file(BytesIO(b'overwrite'), 'profiles/image.png')
        with self.assertRaises(HTTPException):
            await self.storage.delete_file(url.replace('signature=', 'invalid='))

    async def test_profile_read_url_cannot_authorize_deletion(self):
        key = generate_s3_key('profile/user_2', 'profile.webp')
        url = await self.storage.upload_byte_file(BytesIO(b'owner-2'), key)
        for candidate in (url, url.replace('signature=', 'invalid='),
                          url.replace(self.storage.base_url, 'https://foreign.invalid')):
            with self.assertRaises(HTTPException):
                await self.storage.delete_file(candidate)
        for candidate, uploader_id in ((key, 1), (url, 2),
                                       (key.replace('profile/', 'review/'), 2),
                                       ('profile/user_2/../../secret', 2)):
            with self.assertRaises(HTTPException):
                await self.storage.delete_profile_file(candidate, uploader_id=uploader_id)
        self.assertEqual(self.storage.path(key).read_bytes(), b'owner-2')
        # Deletion uses the upload record, not a valid read signature.
        with patch.object(settings, 'SECRET_KEY', 'rotated-synthetic-key'):
            await LocalStorage().delete_profile_file(key, uploader_id=2)
        self.assertFalse(self.storage.path(key).exists())

    async def test_profile_delete_rejects_symlink_escape(self):
        with TemporaryDirectory() as outside:
            (self.storage.root / 'profile').mkdir()
            (self.storage.root / 'profile/user_2').symlink_to(outside, target_is_directory=True)
            key = generate_s3_key('profile/user_2', 'profile.webp')
            target = Path(outside) / key.split('/')[-1]
            target.write_bytes(b'outside')
            with self.assertRaises(HTTPException):
                await self.storage.delete_profile_file(key, uploader_id=2)
            self.assertEqual(target.read_bytes(), b'outside')
