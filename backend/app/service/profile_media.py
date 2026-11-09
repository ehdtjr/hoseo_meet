import logging

from fastapi import HTTPException, UploadFile
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.s3 import S3Manager
from app.models import ProfileMedia, User
from app.utils.s3 import generate_s3_key

logger = logging.getLogger(__name__)


async def replace_profile_media(
    db: AsyncSession, uploader_id: int, file: UploadFile, storage: S3Manager
) -> str:
    key = generate_s3_key(f"profile/user_{uploader_id}", "profile.webp")
    profile_url = await storage.upload_file(file, key)
    commit_started = False
    try:
        # Serialize replacements even when no upload record exists yet.
        user_id = await db.scalar(
            select(User.id).where(User.id == uploader_id).with_for_update()
        )
        if user_id is None:
            raise HTTPException(404, "User not found")
        record = await db.get(ProfileMedia, uploader_id, populate_existing=True)
        previous = (record.key, record.storage_backend) if record else None
        if record is None:
            db.add(ProfileMedia(
                uploader_id=uploader_id, key=key,
                storage_backend=settings.STORAGE_BACKEND,
            ))
        else:
            record.key = key
            record.storage_backend = settings.STORAGE_BACKEND
        await db.execute(
            update(User).where(User.id == uploader_id).values(profile=profile_url)
        )
        await db.flush()
        commit_started = True
        await db.commit()
    except BaseException:
        await db.rollback()
        if not commit_started:
            await _cleanup(storage, key, uploader_id)
        raise

    if previous and previous[1] == settings.STORAGE_BACKEND:
        await _cleanup(storage, previous[0], uploader_id)
    return profile_url


async def _cleanup(storage: S3Manager, key: str, uploader_id: int) -> None:
    try:
        await storage.delete_profile_file(key, uploader_id=uploader_id)
    except Exception:
        # Do not log private URLs, read signatures, or provider exception details.
        logger.warning("Profile media cleanup failed for user %s", uploader_id)
