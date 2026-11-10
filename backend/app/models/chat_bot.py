from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import Integer, String, DateTime, Text, ForeignKey, Index
from sqlalchemy.orm import Mapped, relationship, mapped_column

from app.core.db import Base

if TYPE_CHECKING:
    from app.models.user import User


class ChatBotMessage(Base):
    __tablename__ = 'chat_bot_message'
    __table_args__ = (Index("ix_chat_bot_message_user_id_id", "user_id", "id"),)

    id: Mapped[int] = mapped_column(
    Integer,
        primary_key=True,
        autoincrement=True
    )
    user_id: Mapped[int] = mapped_column(
        ForeignKey("user.id", ondelete="CASCADE"),
    )
    role: Mapped[str] = mapped_column(
        Text,
        nullable=False
    )
    content: Mapped[str] = mapped_column(
        String,
        nullable=False
    )
    timestamp: Mapped[datetime] = mapped_column(
    DateTime(timezone=True),default=datetime.now, onupdate=datetime.now)


    # 관계설정
    user: Mapped["User"] = relationship(
    "User",
        back_populates="chat_bot_messages",)
