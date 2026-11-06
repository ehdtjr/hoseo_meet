from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Integer
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class RandomChatQueue(Base):
    """Durable queue and last match; one outstanding entry per user."""

    __tablename__ = "random_chat_queue"

    user_id: Mapped[int] = mapped_column(
        ForeignKey("user.id", ondelete="CASCADE"), primary_key=True
    )
    queued_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    stream_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("streams.id", ondelete="CASCADE"), nullable=True
    )

    __table_args__ = (
        Index("ix_random_chat_queue_fifo", "stream_id", "queued_at", "user_id"),
        Index("ix_random_chat_queue_expiry", "expires_at"),
    )
