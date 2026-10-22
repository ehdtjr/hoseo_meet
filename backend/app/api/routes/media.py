import mimetypes

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

from app.core.config import settings
from app.core.local_storage import LocalStorage

router = APIRouter()


@router.get("/{key:path}", include_in_schema=False)
async def read_media(key: str, signature: str = ""):
    if settings.STORAGE_BACKEND != "local":
        raise HTTPException(404)
    path = LocalStorage().verify(key, signature)
    if not path.is_file():
        raise HTTPException(404)
    media_type = mimetypes.guess_type(path.name)[0]
    if media_type not in {"image/jpeg", "image/png", "image/webp", "image/gif"}:
        media_type = "application/octet-stream"
    return FileResponse(path, media_type=media_type, headers={
        "Cache-Control": "private, no-store",
        "X-Content-Type-Options": "nosniff",
        "Referrer-Policy": "no-referrer",
        "Content-Security-Policy": "default-src 'none'; sandbox",
    })
