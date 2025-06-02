from typing import List

from sqlalchemy import String, Integer, ForeignKey, Float
from sqlalchemy.orm import Mapped, relationship
from sqlalchemy.testing.schema import mapped_column

from app.core.db import Base


class Tag(Base):
    __tablename__ = "tag"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(50), unique=True)

    user_tags: Mapped[List["UserTag"]] = relationship("UserTag", back_populates="tag")


class UserTag(Base):
    __tablename__ = "user_tag"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("user.id", ondelete="CASCADE"))
    tag_id: Mapped[int] = mapped_column(ForeignKey("tag.id", ondelete="CASCADE"))
    score: Mapped[float] = mapped_column(Float, default=0.0)

    user: Mapped["User"] = relationship("User", back_populates="user_tags")
    tag: Mapped["Tag"] = relationship("Tag", back_populates="user_tags")


