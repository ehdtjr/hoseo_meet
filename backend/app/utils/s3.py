import uuid


def generate_s3_key(prefix: str, filename: str) -> str:
    """
    S3에 저장할 고유한 파일 경로 생성
    """
    return f"{prefix}/{uuid.uuid4().hex}_{filename}"