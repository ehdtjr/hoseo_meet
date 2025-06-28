from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse

app = FastAPI()


class NotFoundException(HTTPException):
    def __init__(self, detail="리소스를 찾을 수 없습니다."):
        super().__init__(status_code=404, detail=detail)


class PermissionDeniedException(HTTPException):
    def __init__(self, detail="권한이 없습니다."):
        super().__init__(status_code=403, detail=detail)


class ConflictException(HTTPException):
    def __init__(self, detail="이미 존재합니다."):
        super().__init__(status_code=409, detail=detail)

class InvalidImageFormatException(HTTPException):
    def __init__(self, detail="지원하지 않는 이미지 형식입니다."):
        super().__init__(status_code=400, detail=detail)


class ImageUploadFailedException(HTTPException):
    def __init__(self, detail="이미지 업로드에 실패했습니다."):
        super().__init__(status_code=500, detail=detail)


# 예외 핸들러 등록
@app.exception_handler(NotFoundException)
async def not_found_exception_handler(exc: NotFoundException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail, "code": "NOT_FOUND"},
    )


@app.exception_handler(PermissionDeniedException)
async def permission_denied_exception_handler(exc: PermissionDeniedException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail, "code": "PERMISSION_DENIED"},
    )


@app.exception_handler(ConflictException)
async def conflict_exception_handler(exc: ConflictException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail, "code": "CONFLICT"},
    )

@app.exception_handler(InvalidImageFormatException)
async def invalid_image_format_handler(exc: InvalidImageFormatException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail, "code": "INVALID_IMAGE_FORMAT"},
    )


@app.exception_handler(ImageUploadFailedException)
async def image_upload_failed_handler(exc: ImageUploadFailedException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail, "code": "IMAGE_UPLOAD_FAILED"},
    )