from datetime import datetime, timedelta, timezone

from sqlalchemy import Integer, ForeignKey, JSON, DateTime, func, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base


class StoryPost(Base):
    __tablename__ = 'story_post'

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    author_id: Mapped[int] = mapped_column(ForeignKey("user.id", ondelete="CASCADE"))
    stream_id: Mapped[int] = mapped_column(ForeignKey("streams.id", ondelete="CASCADE"), nullable=False)
    text_overlay: Mapped[dict] = mapped_column(JSON, nullable=True)
    image_url: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc) + timedelta(hours=24)
    )

    author: Mapped["User"] = relationship("User", back_populates="story_posts")
    stream: Mapped["Stream"] = relationship("Stream",
                                            back_populates="story_post")
