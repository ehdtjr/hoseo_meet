"""Durable per-recipient deliveries, committed with the logical message."""
from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class MessageOutbox(Base):
    __tablename__ = "message_outbox"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    message_id: Mapped[int] = mapped_column(ForeignKey("message.id", ondelete="CASCADE"))
    user_id: Mapped[int] = mapped_column(ForeignKey("user.id", ondelete="CASCADE"))
    stream_id: Mapped[int] = mapped_column(Integer)
    payload: Mapped[str] = mapped_column(Text)
    channel: Mapped[str] = mapped_column(String(16), default="route", server_default="route")
    attempts: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    available_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    completed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    outcome: Mapped[Optional[str]] = mapped_column(String(32))
    last_error: Mapped[Optional[str]] = mapped_column(String(64))

    __table_args__ = (
        Index("message_outbox_recipient", "message_id", "user_id", unique=True),
        Index("message_outbox_channel_pending", "channel", "available_at", "id",
              postgresql_where=completed_at.is_(None)),
    )
