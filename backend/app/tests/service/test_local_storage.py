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
