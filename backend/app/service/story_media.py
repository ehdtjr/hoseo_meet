"""Only server-owned story uploads are eligible for collection."""

import filecmp
import logging
import os
import shutil
from datetime import datetime, timedelta, timezone
from pathlib import Path

from sqlalchemy import JSON, String, and_, cast, or_, select, text
from sqlalchemy.ext.asyncio import AsyncSession

import app.domains.restaurant.model  # noqa: F401 - register URL/history mappers in CLI and Celery

from app.core.config import settings
from app.core.db import Base
from app.core.media_permissions import verify_story_key
from app.core.s3 import S3Manager
from app.models import StoryMedia, StoryPost

logger = logging.getLogger(__name__)


def reference_columns():
    # Include text and JSON history, not just the current story. A copied read
    # URL in another user's profile, review, message or version preserves media.
    return {
        table: [c for c in table.c if isinstance(c.type, (String, JSON))]
        for table in Base.metadata.sorted_tables
        if table.name != StoryMedia.__tablename__
        and any(isinstance(c.type, (String, JSON)) for c in table.c)
    }


async def has_reference(db: AsyncSession, columns: dict, identifier: str) -> bool:
    # URL decoding also applies to the UUID's unreserved ASCII characters.
    # Match literal and percent-encoded characters in SQL so references in text
    # and JSON stay equivalent without loading entire tables into Python.
    # The identifier comes from a validated, server-generated hexadecimal key.
    encoded_pattern = "".join(f"({char}|%{ord(char):02x})" for char in identifier)
    for table, fields in columns.items():
        if await db.scalar(
            select(1)
            .select_from(table)
            .where(
                or_(
                    *(
                        or_(
                            cast(c, String).contains(identifier, autoescape=True),
                            and_(
                                cast(c, String).contains("%", autoescape=True),
                                cast(c, String).regexp_match(encoded_pattern),
                            ),
                        )
                        for c in fields
                    )
                )
            )
            .limit(1)
        ):
            return True
    return False


async def collect_story_media(
    db: AsyncSession,
    storage: S3Manager,
    *,
    key: str | None = None,
    apply: bool = False,
    backup_dir: Path | None = None,
) -> list[str]:
    """Dry-run by default. Locks serialize claims and reference writes on apply.

    Completed ledger rows remain as tombstones; unknown files are never scanned.
    """
    cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
    # New stories store this exact key. Exclude their uploads in one query,
    # before expensive searches through legacy URLs, messages and JSON history.
    # The locked per-record checks below still protect concurrent claims/writes.
    query = (
        select(StoryMedia.key)
        .outerjoin(StoryPost, StoryPost.image_url == StoryMedia.key)
        .where(
            StoryMedia.deleted_at.is_(None),
            StoryMedia.storage_backend == settings.STORAGE_BACKEND,
            StoryPost.id.is_(None),
            or_(StoryMedia.claimed.is_(True), StoryMedia.created_at <= cutoff),
        )
    )
    if key is not None:
        query = query.where(StoryMedia.key == key)
    keys = list((await db.scalars(query.order_by(StoryMedia.key))).all())
    await db.rollback()
    candidates = []
    for candidate in keys:
        try:
            if apply and db.bind.dialect.name == "postgresql":
                await db.execute(text("SET LOCAL lock_timeout = '5s'"))
            record = await db.scalar(
                select(StoryMedia).where(StoryMedia.key == candidate).with_for_update()
            )
            if record is None or record.deleted_at is not None:
                await db.rollback()
                continue
            verify_story_key(record.key, record.uploader_id)
            created_at = (
                record.created_at.replace(tzinfo=timezone.utc)
                if record.created_at.tzinfo is None
                else record.created_at
            )
            if record.storage_backend != settings.STORAGE_BACKEND or (
                not record.claimed and created_at > cutoff
            ):
                await db.rollback()
                continue
            columns = reference_columns()
            # UUID matching also protects URLs whose path separators have
            # been percent-encoded by a legacy client, and copied old origins.
            identifier = record.key.rsplit("/", 1)[-1].split("_", 1)[0]
            if await has_reference(db, columns, identifier):
                await db.rollback()
                continue
            if apply and db.bind.dialect.name == "postgresql":
                # Legacy endpoints can copy URLs without locking our ledger.
                # Lock only actual candidates, then recheck before deleting.
                preparer = db.bind.dialect.identifier_preparer
                tables = ", ".join(
                    preparer.format_table(t)
                    for t in sorted(columns, key=lambda t: t.name)
                )
                await db.execute(text(f"LOCK TABLE {tables} IN SHARE MODE"))
                if await has_reference(db, columns, identifier):
                    await db.rollback()
                    continue
            candidates.append(record.key)
            if apply:
                if backup_dir is not None:
                    if not storage.local:
                        raise RuntimeError(
                            "CLI backups support local storage only; snapshot S3 separately"
                        )
                    source = storage.local.path(record.key)
                    target = backup_dir.resolve() / record.key
                    if not target.resolve().is_relative_to(backup_dir.resolve()):
                        raise ValueError("Invalid backup path")
                    target.parent.mkdir(parents=True, exist_ok=True)
                    if source.exists():
                        # Never replace a previous recovery copy. An interrupted
                        # backup is removed; live file deletion has not begun.
                        try:
                            with target.open("xb") as output, source.open(
                                "rb"
                            ) as input_file:
                                shutil.copyfileobj(input_file, output)
                                output.flush()
                                os.fsync(output.fileno())
                        except FileExistsError:
                            if not filecmp.cmp(source, target, shallow=False):
                                raise RuntimeError("Backup differs from live media")
                        except BaseException:
                            target.unlink(missing_ok=True)
                            raise
                    directory_fd = os.open(target.parent, os.O_RDONLY)
                    try:
                        os.fsync(directory_fd)
                    finally:
                        os.close(directory_fd)
                await storage.delete_story_file(
                    record.key, uploader_id=record.uploader_id
                )
                record.deleted_at = datetime.now(timezone.utc)
                await db.commit()
            else:
                await db.rollback()
        except BaseException:
            await db.rollback()
            raise
    return candidates


async def try_collect_story_media(db: AsyncSession, storage: S3Manager, key: str):
    try:
        await collect_story_media(db, storage, key=key, apply=True)
    except Exception:
        # Durable ledger survives transient storage/DB failures for a later retry.
        logger.warning("Story media cleanup deferred")
