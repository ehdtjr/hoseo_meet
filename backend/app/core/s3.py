from io import BytesIO
from typing import Optional, List
from urllib.parse import urlparse

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

    async def upload_file(self, file: UploadFile, destination_path: str) -> str:
        """
        UploadFile 객체를 S3에 비동기로 업로드
        """
        content_type: Optional[str] = file.content_type or "application/octet-stream"

        session = aioboto3.Session()
        try:
            async with session.client(
                "s3",
                aws_access_key_id=self.aws_access_key_id,
                aws_secret_access_key=self.aws_secret_access_key,
                region_name=self.aws_region,
            ) as s3_client:
                file.file.seek(0)  # 파일 포인터를 처음으로 이동
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
        """
        BytesIO 객체를 S3에 비동기로 업로드하고 URL 반환
        """
        session = aioboto3.Session()
        try:
            async with session.client(
                "s3",
                aws_access_key_id=self.aws_access_key_id,
                aws_secret_access_key=self.aws_secret_access_key,
                region_name=self.aws_region,
            ) as s3_client:
                byte_file.seek(0)  # 파일 포인터를 처음으로 이동
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
        """
        S3에서 파일 비동기로 삭제
        """
        session = aioboto3.Session()
        try:
            parsed_url = urlparse(file_url)
            object_key = parsed_url.path.lstrip("/")  # path 앞의 '/' 제거
            async with session.client(
                "s3",
                aws_access_key_id=self.aws_access_key_id,
                aws_secret_access_key=self.aws_secret_access_key,
                region_name=self.aws_region,
            ) as s3_client:
                await s3_client.delete_object(Bucket=self.bucket_name, Key=object_key)
        except Exception as e:
            raise HTTPException(
                status_code=500, detail=f"Failed to delete file from S3: {str(e)}"
            )

    async def list_room_images(self, room_id: int) -> List[str]:
        """
        특정 방(room_id)에 저장된 이미지 목록을 비동기로 반환
        """
        prefix = f"rooms/{room_id}/"  # 이미지가 저장된 경로
        images = []

        session = aioboto3.Session()
        try:
            async with session.client(
                "s3",
                aws_access_key_id=self.aws_access_key_id,
                aws_secret_access_key=self.aws_secret_access_key,
                region_name=self.aws_region,
            ) as s3_client:
                paginator = s3_client.get_paginator("list_objects_v2")
                async for page in paginator.paginate(
                    Bucket=self.bucket_name, Prefix=prefix
                ):

                    for obj in page.get("Contents", []):
                        key = obj["Key"]
                        file_url = f"{self.cloud_front_domain_url}/{key}"
                        print("file_url", file_url)
                        images.append(file_url)
        except Exception as e:
            raise RuntimeError(f"Failed to list images in room {room_id}: {e}")
        print("images", images)
        return images

    async def list_review_images_by_room(self, room_id: int) -> List[str]:
        """
        특정 room_id에 저장된 리뷰 이미지 목록을 비동기로 반환
        """
        prefix = f"reviews/{room_id}/"  # 리뷰 이미지가 저장된 경로
        images = []

        session = aioboto3.Session()
        try:
            async with session.client(
                "s3",
                aws_access_key_id=self.aws_access_key_id,
                aws_secret_access_key=self.aws_secret_access_key,
                region_name=self.aws_region,
            ) as s3_client:
                paginator = s3_client.get_paginator("list_objects_v2")
                async for page in paginator.paginate(
                    Bucket=self.bucket_name, Prefix=prefix
                ):
                    for obj in page.get("Contents", []):
                        key = obj["Key"]
                        file_url = f"{self.cloud_front_domain_url}/{key}"
                        print("file_url", file_url)
                        images.append(file_url)
        except Exception as e:
            raise RuntimeError(f"Failed to list review images in room {room_id}: {e}")

        print("images", images)
        return images


s3_manager = S3Manager()


async def get_s3_manager() -> S3Manager:
    return S3Manager()
