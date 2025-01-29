from datetime import datetime
from typing import Optional

from sqlalchemy import (Boolean, DateTime, ForeignKey, Index, Integer, String,
                        UniqueConstraint, func, text)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base


class Stream(Base):
    __tablename__ = "streams"
    MAX_NAME_LENGTH = 20

    id: Mapped[int] = mapped_column(Integer, primary_key=True,
                                    autoincrement=True)
    name: Mapped[str] = mapped_column(String(MAX_NAME_LENGTH), index=True,
                                      nullable=False)
    type: Mapped[str] = mapped_column(String(MAX_NAME_LENGTH), index=True,
                                      nullable=False)
    date_created: Mapped[datetime] = mapped_column(DateTime(timezone=True),
                                                   server_default=func.now())

    creator_id: Mapped[int] = mapped_column(
        ForeignKey("user.id", ondelete="SET NULL"))
    recipient_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("recipient.id", ondelete="SET NULL"), nullable=True)

    creator: Mapped["User"] = relationship("User", back_populates="streams")
    recipient: Mapped["Recipient"] = relationship("Recipient",
                                                  back_populates="streams")
    meet_post: Mapped[Optional["MeetPost"]] = relationship(
        "MeetPost", back_populates="stream", uselist=False)
    story_post: Mapped[Optional["StoryPost"]] = relationship(
        "StoryPost", back_populates="stream", uselist=False
    )


class Subscription(Base):
    __tablename__ = "subscriptions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True,
                                    autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("user.id", ondelete="CASCADE"))
    recipient_id: Mapped[int] = mapped_column(
        ForeignKey("recipient.id", ondelete="CASCADE"))

    active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_user_active: Mapped[bool] = mapped_column(Boolean)
    is_muted: Mapped[bool] = mapped_column(Boolean, default=False)

    user: Mapped["User"] = relationship("User", back_populates="subscriptions")
    recipient: Mapped["Recipient"] = relationship("Recipient",
                                                  back_populates="subscriptions")


    __table_args__ = (
        UniqueConstraint("user_id", "recipient_id"),
        Index(
            "subscription_recipient_id_user_id_idx",
            "recipient_id",
            "user_id",
            postgresql_where=text("active = true AND is_user_active = true"),
        ),
    )
