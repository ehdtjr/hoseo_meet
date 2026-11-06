"""Server-owned upload records; profile URLs never establish ownership."""
from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class ProfileMedia(Base):
    # The table itself scopes these uploads to profile use only.
    __tablename__ = "profile_media"

    uploader_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("user.id", ondelete="CASCADE"), primary_key=True
    )
    key: Mapped[str] = mapped_column(String(255), nullable=False, unique=True)
    storage_backend: Mapped[str] = mapped_column(String(20), nullable=False)
