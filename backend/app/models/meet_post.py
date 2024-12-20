from datetime import datetime

from sqlalchemy import (CheckConstraint, DateTime, ForeignKey,
                        Integer, String, func)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base


class MeetPost(Base):
    __tablename__ = "meet_post"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    author_id: Mapped[int] = mapped_column(ForeignKey("user.id", ondelete="CASCADE"))
    stream_id: Mapped[int] = mapped_column(ForeignKey("streams.id", ondelete="CASCADE"))  # 수정
    title: Mapped[str] = mapped_column(String(50), nullable=False)
    type: Mapped[str] = mapped_column(String(50), nullable=False)

    content: Mapped[str] = mapped_column(String(200), nullable=False)

    page_view: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    max_people: Mapped[int] = mapped_column(Integer, nullable=False)

    __table_args__ = (
        CheckConstraint('max_people >= 1 AND max_people <= 50', name='check_max_people'),
    )


# 관계 설정
    author: Mapped["User"] = relationship("User", back_populates="meet_posts")
    stream: Mapped["Stream"] = relationship("Stream", back_populates="meet_post")
