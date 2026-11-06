from io import BytesIO

from app.core.local_storage import LocalStorage
from app.core.media_permissions import reject_profile_url_delete, verify_profile_key
from typing import Optional
from urllib.parse import urlsplit

import aioboto3
from fastapi import UploadFile, HTTPException
from app.core.config import settings


class S3Manager:
    def __init__(self):
        self.bucket_name = settings.S3_BUCKET_NAME
        self.aws_region = settings.AWS_REGION
        self.aws_access_key_id = settings.AWS_ACCESS_KEY_ID
        self.aws_secret_access_key = settings.AWS_SECRET_ACCESS_KEY
        self.cloud_front_domain_url = settings.CLOUD_FRONT_DOMAIN_URL
        self.session = aioboto3.Session() if settings.STORAGE_BACKEND == "s3" else None
        self.local = LocalStorage() if settings.STORAGE_BACKEND == "local" else None

    async def _get_client(self):
        return self.session.client(
            "s3",
            aws_access_key_id=self.aws_access_key_id,
            aws_secret_access_key=self.aws_secret_access_key,
            region_name=self.aws_region,
        )

    async def upload_file(self, file: UploadFile, destination_path: str) -> str:
        if self.local:
            try:
                return await self.local.upload_byte_file(file.file, destination_path)
            finally:
                file.file.close()
        content_type: Optional[str] = file.content_type or "application/octet-stream"
        try:
            async with await self._get_client() as s3_client:
                file.file.seek(0)
                await s3_client.upload_fileobj(
                    file.file,
                    self.bucket_name,
                    destination_path,
                    ExtraArgs={"ContentType": content_type},
                )
                file_url = f"{self.cloud_front_domain_url}/{destination_path}"
                return file_url
        except Exception as e:
            raise HTTPException(
                status_code=500, detail=f"Failed to upload file to S3: {str(e)}"
            )
        finally:
            file.file.close()

    async def upload_byte_file(
        self,
        byte_file: BytesIO,
        destination_path: str,
        content_type: str = "application/octet-stream",
    ) -> str:
        if self.local:
            return await self.local.upload_byte_file(byte_file, destination_path)
        try:
            async with await self._get_client() as s3_client:
                byte_file.seek(0)
                await s3_client.upload_fileobj(
                    byte_file,
                    self.bucket_name,
                    destination_path,
                    ExtraArgs={"ContentType": content_type},
                )
                file_url = f"{self.cloud_front_domain_url}/{destination_path}"
                return file_url
        except Exception as e:
            raise RuntimeError(f"파일 업로드 실패: {e}")

    async def delete_file(self, file_url: str) -> None:
        if self.local:
            return await self.local.delete_file(file_url)
        parsed_url, base = urlsplit(file_url), urlsplit(self.cloud_front_domain_url.rstrip("/"))
        prefix = base.path + "/"
        if (parsed_url.scheme, parsed_url.netloc) != (base.scheme, base.netloc) or not parsed_url.path.startswith(prefix):
            raise HTTPException(400, "Foreign media URL")
        # S3 upload URLs contain the literal key, including any percent escapes
        # in the original filename. Decoding would target a different object.
        object_key = parsed_url.path[len(prefix):]
        reject_profile_url_delete(object_key)
        try:
            async with await self._get_client() as s3_client:
                await s3_client.delete_object(Bucket=self.bucket_name, Key=object_key)
        except Exception as e:
            raise HTTPException(
                status_code=500, detail=f"Failed to delete file from S3: {str(e)}"
            )

    async def delete_profile_file(self, key: str, *, uploader_id: int) -> None:
        # A read URL is deliberately not accepted by this API.
        verify_profile_key(key, uploader_id)
        if self.local:
            return await self.local.delete_profile_file(key, uploader_id=uploader_id)
        async with await self._get_client() as s3_client:
            await s3_client.delete_object(Bucket=self.bucket_name, Key=key)


s3_manager = S3Manager()

async def get_s3_manager() -> S3Manager:
    return s3_manager
