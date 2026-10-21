from io import BytesIO
from PIL import Image, ImageOps


def convert_image_to_webp(file) -> BytesIO:
    """
    이미지를 WebP 형식으로 변환

    Args:
        file: 업로드된 이미지 파일 객체 (지원 형식: JPEG, PNG 등)

    Returns:
        BytesIO: WebP 형식으로 변환된 이미지 데이터
    """
    try:
        image = Image.open(file)
        image = ImageOps.exif_transpose(image)  # EXIF 회전 정보 처리
        output = BytesIO()
        image.save(output, format="WEBP", quality=85)  # WebP 형식으로 저장
        output.seek(0)
        return output
    except Exception as e:
        raise ValueError(f"Failed to convert image to WebP: {str(e)}")
