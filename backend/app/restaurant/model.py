from datetime import datetime
from typing import List

from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy import Integer, String, Text, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from geoalchemy2 import Geography, WKBElement
from sqlalchemy.dialects.postgresql import NUMERIC

from app.core.db import Base


class RestaurantPost(Base):
    __tablename__ = "restaurant_post"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    editor_id: Mapped[int] = mapped_column(ForeignKey("user.id", ondelete="SET NULL"), nullable=True)

    name: Mapped[str] = mapped_column(Text, nullable=False)
    address: Mapped[str] = mapped_column(Text, nullable=False)
    comment: Mapped[str] = mapped_column(Text, nullable=True)
    location: Mapped[WKBElement] = mapped_column(
        Geography(geometry_type="POINT", srid=4326, spatial_index=True),
        nullable=False
    )

    editor: Mapped["User"] = relationship("User", lazy="selectin")
    versions: Mapped[List["RestaurantPostVersion"]] = relationship(
        "RestaurantPostVersion",
        back_populates="post",
        cascade="all, delete-orphan",
        order_by="desc(RestaurantPostVersion.version)"
    )
    menus: Mapped[List["RestaurantMenu"]] = relationship(
        "RestaurantMenu",
        back_populates="post",
        cascade="all, delete-orphan"
    )
    images: Mapped[List["RestaurantPostImage"]] = relationship(
        "RestaurantPostImage",
        back_populates="post",
        cascade="all, delete-orphan"
    )
    reviews: Mapped[List["RestaurantReview"]] = relationship(
        "RestaurantReview",
        back_populates="post",
        cascade="all, delete-orphan"
    )
    hearts: Mapped[List["RestaurantHeart"]] = relationship(
        "RestaurantHeart",
        back_populates="post",
        cascade="all, delete-orphan"
    )


class RestaurantPostVersion(Base):
    __tablename__ = "restaurant_post_version"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    editor_id: Mapped[int] = mapped_column(ForeignKey("user.id", ondelete="SET NULL"), nullable=True)
    post_id: Mapped[int] = mapped_column(ForeignKey("restaurant_post.id", ondelete="CASCADE"))
    version: Mapped[int] = mapped_column(Integer, nullable=False)

    name: Mapped[str] = mapped_column(Text, nullable=False)
    address: Mapped[str] = mapped_column(Text, nullable=False)
    location: Mapped[WKBElement] = mapped_column(
        Geography(geometry_type="POINT", srid=4326), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    editor: Mapped["User"] = relationship("User", lazy="selectin")
    post: Mapped["RestaurantPost"] = relationship("RestaurantPost", back_populates="versions")


class RestaurantMenu(Base):
    __tablename__ = "restaurant_menu"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    editor_id: Mapped[int] = mapped_column(ForeignKey("user.id", ondelete="SET NULL"), nullable=True)
    post_id: Mapped[int] = mapped_column(ForeignKey("restaurant_post.id", ondelete="CASCADE"))
    name: Mapped[str] = mapped_column(Text, nullable=False)
    price: Mapped[int] = mapped_column(Integer, nullable=False)


    editor: Mapped["User"] = relationship("User", lazy="selectin")
    post: Mapped["RestaurantPost"] = relationship("RestaurantPost", back_populates="menus")
    versions: Mapped[List["RestaurantMenuVersion"]] = relationship(
        "RestaurantMenuVersion",
        back_populates="menu",
        cascade="all, delete-orphan",
        order_by="desc(RestaurantMenuVersion.version)"
    )


class RestaurantMenuVersion(Base):
    __tablename__ = "restaurant_menu_version"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    editor_id: Mapped[int] = mapped_column(ForeignKey("user.id", ondelete="SET NULL"), nullable=True)
    menu_id: Mapped[int] = mapped_column(ForeignKey("restaurant_menu.id", ondelete="CASCADE"))
    version: Mapped[int] = mapped_column(Integer, nullable=False)

    name: Mapped[str] = mapped_column(Text, nullable=False)
    price: Mapped[int] = mapped_column(Integer, nullable=False)

    editor: Mapped["User"] = relationship("User", lazy="selectin")

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    menu: Mapped["RestaurantMenu"] = relationship("RestaurantMenu", back_populates="versions")


class RestaurantPostImage(Base):
    __tablename__ = "restaurant_post_image"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    post_id: Mapped[int] = mapped_column(ForeignKey("restaurant_post.id", ondelete="CASCADE"))
    image: Mapped[str] = mapped_column(String(200), nullable=False)

    editor_id: Mapped[int] = mapped_column(ForeignKey("user.id", ondelete="SET NULL"), nullable=True)

    post: Mapped["RestaurantPost"] = relationship("RestaurantPost", back_populates="images")
    editor: Mapped["User"] = relationship("User", lazy="selectin")

class RestaurantPostImageSetVersion(Base):
    __tablename__ = "restaurant_post_image_set_version"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    post_id: Mapped[int] = mapped_column(ForeignKey("restaurant_post.id", ondelete="CASCADE"), nullable=False)
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    image_urls: Mapped[List[str]] = mapped_column(JSON, nullable=False)
    editor_id: Mapped[int] = mapped_column(ForeignKey("user.id", ondelete="SET NULL"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    post: Mapped["RestaurantPost"] = relationship("RestaurantPost", lazy="selectin")
    editor: Mapped["User"] = relationship("User", lazy="selectin")


class RestaurantReview(Base):
    __tablename__ = "restaurant_review"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    post_id: Mapped[int] = mapped_column(ForeignKey("restaurant_post.id", ondelete="CASCADE"))
    author_id: Mapped[int] = mapped_column(ForeignKey("user.id"))
    content: Mapped[str] = mapped_column(String(200), nullable=False)
    rating: Mapped[float] = mapped_column(NUMERIC(3, 1), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    post: Mapped["RestaurantPost"] = relationship("RestaurantPost", back_populates="reviews", lazy="selectin")
    author: Mapped["User"] = relationship("User", lazy="selectin")

    images: Mapped[List["RestaurantReviewImage"]] = relationship(
        "RestaurantReviewImage", back_populates="review", lazy="selectin"
    )


class RestaurantReviewImage(Base):
    __tablename__ = "restaurant_review_image"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    review_id: Mapped[int] = mapped_column(ForeignKey("restaurant_review.id", ondelete="CASCADE"))
    post_id: Mapped[int] = mapped_column(ForeignKey("restaurant_post.id", ondelete="CASCADE"))
    image: Mapped[str] = mapped_column(String(200), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    review: Mapped["RestaurantReview"] = relationship("RestaurantReview", back_populates="images")


class RestaurantHeart(Base):
    __tablename__ = "restaurant_heart"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("user.id", ondelete="CASCADE"), nullable=False)
    post_id: Mapped[int] = mapped_column(Integer, ForeignKey("restaurant_post.id", ondelete="CASCADE"), nullable=False)

    __table_args__ = (
        UniqueConstraint("user_id", "post_id", name="uq_user_post_heart"),
    )

    user: Mapped["User"] = relationship("User", lazy="selectin")
    post: Mapped["RestaurantPost"] = relationship("RestaurantPost", back_populates="hearts", lazy="selectin")
