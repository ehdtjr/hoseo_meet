# file: app/core/s3.py
import boto3
from fastapi import UploadFile
from typing import List

AWS_ACCESS_KEY_ID = "YOUR_KEY"
AWS_SECRET_ACCESS_KEY = "YOUR_SECRET"
AWS_REGION = "ap-northeast-2"
S3_BUCKET_NAME = "campus-meet-bucket"

# boto3 클라이언트 생성
s3_client = boto3.client(
    "s3",
    aws_access_key_id=AWS_ACCESS_KEY_ID,
    aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
    region_name=AWS_REGION,
)

def upload_file_to_s3(file: UploadFile, destination_path: str) -> str:
    """
    file: FastAPI UploadFile
    destination_path: S3 내 저장될 경로 (ex: "reviews/{review_id}/{filename}")
    return: 업로드된 S3 객체 URL
    """
    # S3에 업로드
    file.file.seek(0)  # UploadFile은 file-like object
    s3_client.upload_fileobj(file.file, S3_BUCKET_NAME, destination_path)

    # 업로드된 파일의 URL
    file_url = f"https://{S3_BUCKET_NAME}.s3.{AWS_REGION}.amazonaws.com/{destination_path}"
    return file_url
