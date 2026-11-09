"""Local media: authenticated uploads, capability URLs for image clients."""
import asyncio
import hashlib
import hmac
import os
import shutil
import tempfile
from pathlib import Path, PurePosixPath
from urllib.parse import parse_qs, quote, unquote, urlsplit

from fastapi import HTTPException

from app.core.config import settings
from app.core.media_permissions import reject_profile_url_delete, verify_profile_key


class LocalStorage:
    def __init__(self):
        self.root = settings.LOCAL_MEDIA_ROOT.resolve()
        self.base_url = settings.MEDIA_BASE_URL.rstrip("/")

    def path(self, key: str) -> Path:
        parts = PurePosixPath(key).parts
        if not parts or key.startswith("/") or "\\" in key or any(p in (".", "..") for p in key.split("/")):
            raise HTTPException(400, "Invalid media path")
        path = (self.root / key).resolve()
        if not path.is_relative_to(self.root) or path == self.root:
            raise HTTPException(400, "Invalid media path")
        return path

    def signature(self, key: str) -> str:
        return hmac.new(settings.SECRET_KEY.encode(), ("media:" + key).encode(), hashlib.sha256).hexdigest()

    def verify(self, key: str, signature: str) -> Path:
        path = self.path(key)
        if not hmac.compare_digest(self.signature(key), signature):
            raise HTTPException(403, "Invalid media signature")
        return path

    async def upload_byte_file(self, file, destination_path: str) -> str:
        path = self.path(destination_path)

        def write():
            path.parent.mkdir(parents=True, exist_ok=True)
            # Publish only complete files. link() preserves exclusive creation.
            fd, temporary = tempfile.mkstemp(prefix=".upload-", dir=path.parent)
            try:
                with os.fdopen(fd, "wb") as target:
                    file.seek(0)
                    shutil.copyfileobj(file, target)
                    target.flush()
                    os.fsync(target.fileno())
                os.link(temporary, path)
            finally:
                os.unlink(temporary)

        task = asyncio.create_task(asyncio.to_thread(write))
        try:
            await asyncio.shield(task)
        except asyncio.CancelledError:
            # to_thread continues after cancellation; wait before closing the
            # input, and remove only a destination this write actually created.
            try:
                await task
            except Exception:
                pass
            else:
                path.unlink(missing_ok=True)
            raise
        return self.url(destination_path)

    def url(self, key: str) -> str:
        self.path(key)
        return f"{self.base_url}/{quote(key, safe='/')}?signature={self.signature(key)}"

    async def delete_file(self, file_url: str) -> None:
        parsed, base = urlsplit(file_url), urlsplit(self.base_url)
        prefix = base.path + "/"
        if (parsed.scheme, parsed.netloc) != (base.scheme, base.netloc) or not parsed.path.startswith(prefix):
            raise HTTPException(400, "Foreign media URL")
        key = unquote(parsed.path[len(prefix):])
        signature = parse_qs(parsed.query).get("signature", [""])[0]
        path = self.verify(key, signature)
        reject_profile_url_delete(key)
        await asyncio.to_thread(path.unlink, missing_ok=True)

    async def delete_profile_file(self, key: str, *, uploader_id: int) -> None:
        # Callers must obtain the key from the server-owned upload record.
        verify_profile_key(key, uploader_id)
        path = self.path(key)
        await asyncio.to_thread(path.unlink, missing_ok=True)
