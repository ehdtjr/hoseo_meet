from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class UserTaggingCheckpoint(Base):
    __tablename__ = "user_tagging_checkpoint"
    __table_args__ = (
        CheckConstraint(
            "status IN ('pending', 'running', 'failed', 'completed')",
            name="ck_user_tagging_checkpoint_status",
        ),
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("user.id", ondelete="CASCADE"), primary_key=True
    )
    analysis_version: Mapped[str] = mapped_column(String(50))
    status: Mapped[str] = mapped_column(String(20), default="pending")
    # Message IDs are watermarks, not FKs: deleting chat history must not move
    # the cursor backwards or remove the record of a completed analysis.
    last_message_id: Mapped[int] = mapped_column(Integer, default=0)
    target_message_id: Mapped[int] = mapped_column(Integer, default=0)
    last_error: Mapped[str | None] = mapped_column(String(100), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
