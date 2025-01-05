import boto3
from fastapi import UploadFile
from typing import Optional, List
from app.core.config import settings
from urllib.parse import urlparse


class S3Manager:
    def __init__(self):
        self.s3_client = boto3.client(
            "s3",
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
            region_name=settings.AWS_REGION,
        )
        self.bucket_name = settings.S3_BUCKET_NAME

    def upload_file(self, file: UploadFile, destination_path: str) -> str:
        content_type: Optional[str] = file.content_type or "application/octet-stream"

        try:
            file.file.seek(0)  # 파일 포인터를 처음으로 이동
            self.s3_client.upload_fileobj(
                file.file,
                self.bucket_name,
                destination_path,
                ExtraArgs={
                    "ContentType": content_type,
                },
            )
            file_url = f"https://{self.bucket_name}.s3.{self.s3_client.meta.region_name}.amazonaws.com/{destination_path}"
            return file_url
        except Exception as e:
            raise RuntimeError(f"Failed to upload file to S3: {e}")

    async def delete_file(self, file_url: str) -> None:
        parsed_url = urlparse(file_url)
        object_key = parsed_url.path.lstrip("/")  # path 앞의 '/' 제거
        bucket_name = parsed_url.netloc.split(".")[0]
        self.s3_client.delete_object(Bucket=bucket_name, Key=object_key)

    def list_room_images(self, room_id: int) -> List[str]:

        prefix = f"rooms/{room_id}/"  # 이미지가 저장된 경로

        response = self.s3_client.list_objects_v2(
            Bucket=self.bucket_name,
            Prefix=prefix
        )
        images: List[str] = []

        # response에 "Contents"가 없으면 해당 prefix에 오브젝트가 없는 것
        if "Contents" in response:
            for obj in response["Contents"]:
                key = obj["Key"]  # 예: "rooms/10/abc.png"
                file_url = f"https://{self.bucket_name}.s3.{self.s3_client.meta.region_name}.amazonaws.com/{key}"
                images.append(file_url)

        return images

s3_manager = S3Manager()
