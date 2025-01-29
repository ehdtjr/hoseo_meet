from datetime import datetime
from enum import Enum as PyEnum
from typing import List, Optional

from sqlalchemy import (Boolean, Computed, DateTime, Enum, ForeignKey, Index,
                        Integer, String, text)
from sqlalchemy.dialects.postgresql import TSVECTOR
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base


class MessageType(PyEnum):
    NORMAL = 1
    RESOLVE_TOPIC_NOTIFICATION = 2


class Message(Base):
    __tablename__ = "message"

    id: Mapped[int] = mapped_column(Integer, primary_key=True,
                                    autoincrement=True)
    sender_id: Mapped[int] = mapped_column(
        ForeignKey("user.id", ondelete="CASCADE"))
    type: Mapped[MessageType] = mapped_column(
        Enum(MessageType), default=MessageType.NORMAL, nullable=False
    )
    recipient_id: Mapped[int] = mapped_column(
        ForeignKey("recipient.id", ondelete="CASCADE")
    )
    content: Mapped[str] = mapped_column(String)
    rendered_content: Mapped[Optional[str]] = mapped_column(String,
                                                            nullable=True)
    date_sent: Mapped[datetime] = mapped_column(DateTime(timezone=True),
                                                default=datetime.now, onupdate=datetime.now)
    has_attachment: Mapped[bool] = mapped_column(Boolean, default=False,
                                                 index=True)
    has_image: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    has_link: Mapped[bool] = mapped_column(Boolean, default=False, index=True)

    # 관계 설정
    sender: Mapped["User"] = relationship("User",
                                          back_populates="messages")
    user_messages: Mapped[List["UserMessage"]] = (
        relationship("UserMessage",
                     back_populates="message"))

    # 검색 엔진을 위한 컬럼
    search_tsvector = mapped_column(
        TSVECTOR,
        Computed("to_tsvector('simple', content)", persisted=True),
        index=True
    )

    __table_args__ = (
        Index("message_search_tsvector_idx", search_tsvector,
              postgresql_using="gin"),
        # 메시지를 이동하거나 읽음 표시할 때 사용
        Index("message_recipient", "recipient_id", "id"),
        # 발신자와 수신자 기반 메시지 필터링
        Index("message_sender_recipient", "sender_id",
              "recipient_id"),
    )


class UserMessage(Base):
    __tablename__ = "user_message"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("user.id", ondelete="CASCADE"))
    message_id: Mapped[int] = mapped_column(ForeignKey("message.id", ondelete="CASCADE"))
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)

    user: Mapped["User"] = relationship("User", back_populates="user_messages")
    message: Mapped["Message"] = relationship("Message", back_populates="user_messages")

    __table_args__ = (
        # 기존 인덱스
        Index("user_message_user_id_is_read_msgid_idx", "user_id", "is_read", "message_id"),

        # 새 부분 인덱스 (PostgreSQL 전용), is_read = false인 행만 인덱싱
        Index(
            "idx_user_message_unread",
            "message_id",
            postgresql_where=text("is_read = false")
        ),
    )