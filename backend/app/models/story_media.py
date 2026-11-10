"""Durable upload provenance and retry ledger, retained after story/user deletion."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class StoryMedia(Base):
    __tablename__ = "story_media"

    key: Mapped[str] = mapped_column(String(255), primary_key=True)
    uploader_id: Mapped[int] = mapped_column(Integer, nullable=False)
    storage_backend: Mapped[str] = mapped_column(String(20), nullable=False)
    # Compatibility token for clients that still POST the upload URL.
    upload_url: Mapped[str] = mapped_column(Text, nullable=False, unique=True)
    claimed: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    deleted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
