from datetime import datetime
from typing import List, Optional

from geoalchemy2 import Geography, WKBElement
from sqlalchemy import (
    NUMERIC,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base
from app.models.user import User


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
    location: Mapped[WKBElement] = mapped_column(
        Geography(geometry_type='POINT', srid=4326, spatial_index=True),
        nullable=False
    )


    images: Mapped[Optional[List["RoomPostImage"]]] = relationship(
        "RoomPostImage",
        back_populates="room",
        lazy="selectin"
    )
    reviews: Mapped[List["RoomReview"]] = relationship(
        "RoomReview",
        back_populates="room",
        lazy="selectin",  # Eager loading
    )


class RoomPostImage(Base):
    __tablename__ = "room_post_image"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    room_id: Mapped[int] = mapped_column(Integer, ForeignKey("room_post.id"), nullable=False)
    image: Mapped[str] = mapped_column(String(200), nullable=False)

    room: Mapped["RoomPost"] = relationship("RoomPost", back_populates="images")


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

    review: Mapped["RoomReview"] = relationship("RoomReview", back_populates="images")
