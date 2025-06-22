from datetime import datetime
from typing import List

from fastapi_users_db_sqlalchemy import (
    SQLAlchemyBaseUserTable,
    SQLAlchemyBaseOAuthAccountTable,
)

from sqlalchemy import DateTime, ForeignKey, Integer, String, func
from sqlalchemy.ext.declarative import declared_attr
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql.sqltypes import Boolean

from app.core.db import Base


# User 모델 정의
class User(SQLAlchemyBaseUserTable, Base):
    __tablename__ = "user"  # 테이블 이름 지정

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(length=255), nullable=False, unique=True)
    gender: Mapped[str] = mapped_column(String(length=20), nullable=False)
    profile: Mapped[str] = mapped_column(String(length=1024), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    # 관계 설정
    fcm_token: Mapped["UserFCMToken"] = relationship(
        "UserFCMToken", back_populates="user"
    )
    subscriptions: Mapped[List["Subscription"]] = relationship(
        "Subscription", back_populates="user"
    )
    messages: Mapped[List["Message"]] = relationship("Message", back_populates="sender")
    user_messages: Mapped[List["UserMessage"]] = relationship(
        "UserMessage", back_populates="user"
    )
    streams: Mapped[List["Stream"]] = relationship("Stream", back_populates="creator")

    meet_posts: Mapped[List["MeetPost"]] = relationship(
        "MeetPost", back_populates="author"
    )
    story_posts: Mapped[List["StoryPost"]] = relationship("StoryPost", back_populates="author")

    oauth_accounts: Mapped[List["OAuthAccount"]] = relationship(
        "OAuthAccount", lazy="joined"
    )
    reports_made: Mapped[List["UserReport"]] = relationship(
        "UserReport", back_populates="reporter", foreign_keys="[UserReport.reporter_id]"
    )

    reports_received: Mapped[List["UserReport"]] = relationship(
        "UserReport", back_populates="reported_user", foreign_keys="[UserReport.reported_user_id]"
    )
    term_agreements: Mapped[List["UserTermAgreement"]] = relationship(
        "UserTermAgreement", back_populates="user",
        cascade="all, delete-orphan"
    )


    reviews: Mapped[List["RoomReview"]] = relationship(
        "RoomReview", back_populates="author", lazy="selectin"  # 또는 joined 등
    )
    chat_bot_messages: Mapped[List["ChatBotMessage"]] = relationship(
        "ChatBotMessage",
        back_populates="user",
        cascade="all, delete-orphan",
    )
    hearts: Mapped[list["RoomPostHeart"]] = relationship(
        "RoomPostHeart",
        back_populates="user",
        lazy="selectin",
        cascade="all, delete-orphan"
    )


    # tag
    user_tags: Mapped[List["UserTag"]] = relationship(
        "UserTag", back_populates="user", cascade="all, delete-orphan"
    )

    #Restaurant 관련 역참조 추가
    restaurant_posts: Mapped[List["RestaurantPost"]] = relationship(
        "RestaurantPost",
        back_populates="editor",
        cascade="all, delete-orphan"
    )
    restaurant_post_versions: Mapped[List["RestaurantPostVersion"]] = relationship(
        "RestaurantPostVersion",
        back_populates="editor",
        cascade="all, delete-orphan"
    )
    restaurant_post_images: Mapped[List["RestaurantPostImage"]] = relationship(
        "RestaurantPostImage",
        back_populates="editor",
        cascade="all, delete-orphan"
    )
    restaurant_post_image_set_versions: Mapped[List["RestaurantPostImageSetVersion"]] = relationship(
        "RestaurantPostImageSetVersion",
        back_populates="editor",
        cascade="all, delete-orphan"
    )
    restaurant_menus: Mapped[List["RestaurantMenu"]] = relationship(
        "RestaurantMenu",
        back_populates="editor",
        cascade="all, delete-orphan"
    )
    restaurant_menu_versions: Mapped[List["RestaurantMenuVersion"]] = relationship(
        "RestaurantMenuVersion",
        back_populates="editor",
        cascade="all, delete-orphan"
    )


class UserReport(Base):
    __tablename__ = "user_report"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    reporter_id: Mapped[int] = mapped_column(ForeignKey("user.id"), nullable=False)
    reported_user_id: Mapped[int] = mapped_column(ForeignKey("user.id"), nullable=False)
    reason: Mapped[str] = mapped_column(String(length=500), nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    is_resolved: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    reporter: Mapped["User"] = relationship(
        "User", foreign_keys=[reporter_id], back_populates="reports_made"
    )
    reported_user: Mapped["User"] = relationship(
        "User", foreign_keys=[reported_user_id], back_populates="reports_received"
    )

# UserLocation 모델 정의
class UserFCMToken(Base):
    __tablename__ = "user_fcm_token"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("user.id"))
    fcm_token: Mapped[str] = mapped_column(String(length=255), nullable=False)

    user: Mapped["User"] = relationship("User", back_populates="fcm_token")


class OAuthAccount(SQLAlchemyBaseOAuthAccountTable[int], Base):
    __tablename__ = "oauth_account"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    # oauth_name: Mapped[str] = mapped_column(String(length=255), nullable=False)
    # account_id: Mapped[str] = mapped_column(String(length=255), nullable=False)
    # account_email: Mapped[str] = mapped_column(String(length=255), nullable=False)
    # refresh_token: Mapped[str] = mapped_column(String(length=255), nullable=True)

    @declared_attr
    def user_id(cls) -> Mapped[int]:
        return mapped_column(
            Integer, ForeignKey("user.id", ondelete="cascade"), nullable=False
        )
