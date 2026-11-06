from io import BytesIO
from unittest import IsolatedAsyncioTestCase
from unittest.mock import AsyncMock

from fastapi import HTTPException, UploadFile

from app.core.s3 import S3Manager
from app.utils.s3 import generate_s3_key


class TestS3ProfileDeletion(IsolatedAsyncioTestCase):
    def setUp(self):
        storage = S3Manager()
        storage.local = None
        storage.cloud_front_domain_url = 'https://media.example.test/media'
        storage.bucket_name = 'synthetic-bucket'
        client = AsyncMock()
        context = AsyncMock()
        context.__aenter__.return_value = client
        storage._get_client = AsyncMock(return_value=context)
        self.storage = storage
        self.client = client

    async def test_only_owned_profile_keys_reach_s3(self):
        storage, client = self.storage, self.client
        key = generate_s3_key('profile/user_2', 'profile.webp')
        url = f'{storage.cloud_front_domain_url}/{key}'
        for candidate in (url, url + '?signature=forged',
                          url.replace('media.example.test', 'foreign.invalid')):
            with self.assertRaises(HTTPException):
                await storage.delete_file(candidate)
        for candidate, uploader_id in ((key, 1), (url, 2),
                                       (key.replace('profile/', 'review/'), 2),
                                       ('profile/user_2/../../secret', 2)):
            with self.assertRaises(HTTPException):
                await storage.delete_profile_file(candidate, uploader_id=uploader_id)
        client.delete_object.assert_not_awaited()
        await storage.delete_profile_file(key, uploader_id=2)
        client.delete_object.assert_awaited_once_with(Bucket='synthetic-bucket', Key=key)

    async def test_upload_file_and_delete_preserve_literal_key(self):
        for name in ('discount%20.webp', 'literal%2Fname.webp', '한글.webp', 'plain.webp'):
            with self.subTest(filename=name):
                key = generate_s3_key('reviews/1/1', name)
                url = await self.storage.upload_file(
                    UploadFile(filename=name, file=BytesIO(b'synthetic-image')), key
                )
                await self.storage.delete_file(url)
                self.assertEqual(self.client.upload_fileobj.call_args.args[2], key)
                self.client.delete_object.assert_awaited_with(Bucket='synthetic-bucket', Key=key)

    async def test_upload_bytes_and_delete_preserve_literal_key(self):
        key = generate_s3_key('reviews/1/1', 'discount%20.webp')
        url = await self.storage.upload_byte_file(BytesIO(b'synthetic-image'), key, 'image/webp')
        await self.storage.delete_file(url)
        self.assertEqual(self.client.upload_fileobj.call_args.args[2], key)
        self.client.delete_object.assert_awaited_once_with(Bucket='synthetic-bucket', Key=key)

    async def test_delete_existing_raw_url_preserves_literal_key(self):
        key = 'reviews/1/1/legacy_discount%20.webp'
        await self.storage.delete_file(f'{self.storage.cloud_front_domain_url}/{key}')
        self.client.delete_object.assert_awaited_once_with(Bucket='synthetic-bucket', Key=key)
