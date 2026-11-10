"""Inspect owned orphan uploads; --apply requires an external backup directory."""

import argparse
import asyncio
import os
import shutil
from pathlib import Path

from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.config import settings
from app.core.s3 import S3Manager
from app.core.media_permissions import verify_story_key
from app.models import StoryMedia
from app.service.story_media import collect_story_media


async def run(*, apply=False, backup_dir=None):
    engine = create_async_engine(
        str(settings.SQLALCHEMY_DATABASE_URI), poolclass=NullPool
    )
    try:
        async with async_sessionmaker(engine, expire_on_commit=False)() as db:
            return await collect_story_media(
                db, S3Manager(), apply=apply, backup_dir=backup_dir
            )
    finally:
        await engine.dispose()


def restore_local_file(storage: S3Manager, backup: Path, key: str, uploader_id: int):
    verify_story_key(key, uploader_id)
    if not storage.local:
        raise ValueError("Restore supports local storage only")
    source = (backup.resolve() / key).resolve()
    if not source.is_relative_to(backup.resolve()):
        raise ValueError("Invalid backup path")
    target = storage.local.path(key)
    target.parent.mkdir(parents=True, exist_ok=True)
    # Exclusive creation: never overwrite a file changed since collection.
    with source.open("rb") as input_file:
        try:
            with target.open("xb") as output:
                shutil.copyfileobj(input_file, output)
                output.flush()
                os.fsync(output.fileno())
        except FileExistsError:
            raise
        except BaseException:
            target.unlink(missing_ok=True)
            raise


async def restore(backup: Path, key: str):
    engine = create_async_engine(
        str(settings.SQLALCHEMY_DATABASE_URI), poolclass=NullPool
    )
    try:
        async with async_sessionmaker(engine)() as db:
            record = await db.get(StoryMedia, key)
            if record is None or record.storage_backend != "local":
                raise ValueError("A local upload provenance record is required")
            restore_local_file(S3Manager(), backup, key, record.uploader_id)
    finally:
        await engine.dispose()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--backup-dir", type=Path)
    parser.add_argument("--restore-key")
    args = parser.parse_args()
    if args.restore_key:
        if args.apply or args.backup_dir is None:
            parser.error(
                "--restore-key requires --backup-dir and cannot combine with --apply"
            )
        asyncio.run(restore(args.backup_dir, args.restore_key))
        print(
            "Restored file; restore matching database snapshot before resuming writers"
        )
        return
    if args.apply:
        if settings.STORAGE_BACKEND != "local" or args.backup_dir is None:
            parser.error(
                "--apply requires local storage and --backup-dir (S3: use provider snapshots)"
            )
        backup = args.backup_dir.resolve()
        media = settings.LOCAL_MEDIA_ROOT.resolve()
        if backup.is_relative_to(media) or media.is_relative_to(backup):
            parser.error(
                "backup directory and live media must be separate directory trees"
            )
    keys = asyncio.run(run(apply=args.apply, backup_dir=args.backup_dir))
    for key in keys:
        print(("collected " if args.apply else "candidate ") + key)
    print(
        f"{len(keys)} owned unreferenced uploads; "
        + ("applied" if args.apply else "dry-run")
    )


if __name__ == "__main__":
    main()
