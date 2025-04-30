from datetime import datetime

from sqlalchemy import Integer, String, DateTime, Text, ForeignKey
from sqlalchemy.orm import Mapped, relationship, mapped_column

from app.core.db import Base


class ChatBotMessage(Base):
    __tablename__ = 'chat_bot_message'

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