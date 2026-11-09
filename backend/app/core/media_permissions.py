"""Deletion rules for server-issued profile keys, separate from read signatures."""
import re

from fastapi import HTTPException


def verify_profile_key(key: str, uploader_id: int) -> None:
    if uploader_id <= 0 or not re.fullmatch(
        rf"profile/user_{uploader_id}/[0-9a-f]{{32}}_profile\.webp", key
    ):
        raise HTTPException(403, "Profile media ownership mismatch")


def reject_profile_url_delete(key: str) -> None:
    if key.startswith(("profile/", "story_post/")):
        raise HTTPException(403, "Media deletion requires an upload record")


def verify_story_key(key: str, uploader_id: int) -> None:
    if uploader_id <= 0 or not re.fullmatch(
        rf"story_post/{uploader_id}/[0-9a-f]{{32}}_story\.webp", key
    ):
        raise HTTPException(403, "Story media ownership mismatch")
