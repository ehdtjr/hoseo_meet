from datetime import datetime

# List는 typing에서 import
from typing import List, Optional

from app.models.user import User
from sqlalchemy import (
    NUMERIC,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    Float,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base


class RoomPost(Base):
    __tablename__ = "room_post"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(50), nullable=False)
    address: Mapped[str] = mapped_column(String(50), nullable=False)
    contact: Mapped[str] = mapped_column(String(50), nullable=True)
    price: Mapped[str] = mapped_column(String(50), nullable=True)
    fee: Mapped[str] = mapped_column(String(50), nullable=True)
    options: Mapped[str] = mapped_column(String(200), nullable=True)
    gas_type: Mapped[str] = mapped_column(String(50), nullable=True)
    comment: Mapped[str] = mapped_column(String(200), nullable=True)
    place: Mapped[str] = mapped_column(String(50), nullable=False)
    latitude: Mapped[float] = mapped_column(Float(30), nullable=False)
    longitude: Mapped[float] = mapped_column(Float(30), nullable=False)

    # 방(Post)에서 리뷰이미지를 참조할 때
    images: Mapped[List["RoomReviewImage"]] = relationship(
        "RoomReviewImage",
        back_populates="room",
        lazy="selectin",  # Eager loading(비동기 환경에서 lazy 문제 방지)
    )

    reviews: Mapped[List["RoomReview"]] = relationship(
        "RoomReview",
        back_populates="room",
        lazy="selectin",  # Eager loading
    )


class RoomReview(Base):
    __tablename__ = "room_review"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    room_id: Mapped[int] = mapped_column(ForeignKey("room_post.id", ondelete="CASCADE"))
    author_id: Mapped[int] = mapped_column(ForeignKey("user.id"))
    content: Mapped[str] = mapped_column(Text, nullable=False)
    rating: Mapped[float] = mapped_column(NUMERIC(3, 1), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.now, server_default=func.now()
    )

    room: Mapped["RoomPost"] = relationship(
        "RoomPost",
        back_populates="reviews",
        lazy="selectin",
    )

    author: Mapped["User"] = relationship(
        "User", back_populates="reviews", lazy="selectin"
    )

    images: Mapped[List["RoomReviewImage"]] = relationship(
        "RoomReviewImage",
        back_populates="review",
        lazy="selectin",  # 지연로딩 대신 selectin 로딩
    )


class RoomReviewImage(Base):
    __tablename__ = "room_review_image"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    review_id: Mapped[int] = mapped_column(
        ForeignKey("room_review.id", ondelete="CASCADE")
    )
    room_id: Mapped[int] = mapped_column(ForeignKey("room_post.id", ondelete="CASCADE"))
    image: Mapped[str] = mapped_column(String(200), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.now, server_default=func.now()
    )

    room: Mapped["RoomPost"] = relationship("RoomPost", back_populates="images")
    review: Mapped["RoomReview"] = relationship("RoomReview", back_populates="images")
