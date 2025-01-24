import uuid
from io import BytesIO
from typing import Optional, List
from urllib.parse import urlparse

import aioboto3
from PIL import Image, ImageOps
from fastapi import UploadFile, HTTPException
from app.core.config import settings


class S3Manager:
    def __init__(self):
        self.bucket_name = settings.S3_BUCKET_NAME
        self.aws_region = settings.AWS_REGION
        self.aws_access_key_id = settings.AWS_ACCESS_KEY_ID
        self.aws_secret_access_key = settings.AWS_SECRET_ACCESS_KEY
        self.session = aioboto3.Session()

    async def get_s3_client(self):
        """
        S3 클라이언트 생성
        """
        return self.session.client(
            "s3",
            aws_access_key_id=self.aws_access_key_id,
            aws_secret_access_key=self.aws_secret_access_key,
            region_name=self.aws_region,
        )

    def generate_s3_key(self, prefix: str, filename: str) -> str:
        """
        S3에 저장할 고유한 파일 경로 생성
        """
        return f"{prefix}/{uuid.uuid4().hex}_{filename}"

    async def upload_file(self, file: UploadFile, destination_path: str) -> str:
        """
        UploadFile 객체를 S3에 비동기로 업로드
        """
        content_type: Optional[str] = file.content_type or "application/octet-stream"

        try:
            async with self.get_s3_client() as s3_client:
                file.file.seek(0)  # 파일 포인터를 처음으로 이동
                await s3_client.upload_fileobj(
                    file.file,
                    self.bucket_name,
                    destination_path,
                    ExtraArgs={"ContentType": content_type},
                )
                file_url = f"https://{self.bucket_name}.s3.{self.aws_region}.amazonaws.com/{destination_path}"
                return file_url
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to upload file to S3: {str(e)}")
        finally:
            file.file.close()  # 파일 닫기

    async def upload_byte_file(self, byte_file: BytesIO, destination_path: str, content_type: str = "application/octet-stream") -> str:
        """
        BytesIO 객체를 S3에 비동기로 업로드하고 URL 반환
        """
        try:
            async with self.get_s3_client() as s3_client:
                byte_file.seek(0)  # 파일 포인터를 처음으로 이동
                await s3_client.upload_fileobj(
                    byte_file,
                    self.bucket_name,
                    destination_path,
                    ExtraArgs={"ContentType": content_type},
                )
                file_url = f"https://{self.bucket_name}.s3.{self.aws_region}.amazonaws.com/{destination_path}"
                return file_url
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to upload byte file to S3: {str(e)}")
        finally:
            byte_file.close()  # 파일 닫기

    async def save_image_as_webp_to_s3(self, file: UploadFile, user_id: int) -> str:
        """
        이미지를 WebP로 변환하여 S3에 비동기로 저장하고 URL 반환
        """
        try:
            # 이미지 열기 및 변환
            image = Image.open(file.file)
            image = ImageOps.exif_transpose(image)  # EXIF 회전 정보 처리
            output = BytesIO()
            image.save(output, format="WEBP", quality=85)
            output.seek(0)

            # S3 경로 생성
            unique_filename = self.generate_s3_key(f"profile_images/user_{user_id}", "profile.webp")

            # S3 업로드
            file_url = await self.upload_byte_file(
                byte_file=output,
                destination_path=unique_filename,
                content_type="image/webp",
            )
            return file_url
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error processing and uploading image: {str(e)}")

    async def delete_file(self, file_url: str) -> None:
        """
        S3에서 파일 비동기로 삭제
        """
        try:
            parsed_url = urlparse(file_url)
            object_key = parsed_url.path.lstrip("/")  # path 앞의 '/' 제거
            async with self.get_s3_client() as s3_client:
                await s3_client.delete_object(Bucket=self.bucket_name, Key=object_key)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to delete file from S3: {str(e)}")

    async def list_room_images(self, room_id: int) -> List[str]:
        """
        특정 방(room_id)에 저장된 이미지 목록을 비동기로 반환
        """
        prefix = f"rooms/{room_id}/"  # 이미지가 저장된 경로
        images = []

        try:
            async with self.get_s3_client() as s3_client:
                paginator = s3_client.get_paginator("list_objects_v2")
                async for page in paginator.paginate(Bucket=self.bucket_name, Prefix=prefix):
                    for obj in page.get("Contents", []):
                        key = obj["Key"]
                        file_url = f"https://{self.bucket_name}.s3.{self.aws_region}.amazonaws.com/{key}"
                        images.append(file_url)
        except Exception as e:
            raise RuntimeError(f"Failed to list images in room {room_id}: {e}")

        return images


s3_manager = S3Manager()
