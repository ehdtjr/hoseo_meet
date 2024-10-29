from datetime import datetime
from typing import List

from fastapi_users.db import SQLAlchemyBaseUserTable
from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, \
    func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base


# User 모델 정의
class User(SQLAlchemyBaseUserTable, Base):
    __tablename__ = "user"  # 테이블 이름 지정

    id: Mapped[int] = mapped_column(Integer, primary_key=True,
                                    autoincrement=True)
    name: Mapped[str] = mapped_column(String(length=255), nullable=False)
    gender: Mapped[str] = mapped_column(String(length=20), nullable=False)
    profile: Mapped[str] = mapped_column(String(length=1024), nullable=True)
    is_online: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True),
                                                 server_default=func.now())

    # 관계 설정
    locations: Mapped[List["UserLocation"]] = relationship("UserLocation",
                                                           back_populates="user")
    fcm_token: Mapped["UserFCMToken"] = relationship("UserFCMToken",
                                                     back_populates="user")
    subscriptions: Mapped[List["Subscription"]] = relationship("Subscription",
                                                               back_populates="user")
    messages: Mapped[List["Message"]] = relationship("Message",
                                                     back_populates="sender")
    user_messages: Mapped[List["UserMessage"]] = relationship("UserMessage",
                                                              back_populates="user")
    streams: Mapped[List["Stream"]] = relationship("Stream",
                                                   back_populates="creator")
    meet_posts: Mapped[List["MeetPost"]] = relationship("MeetPost",
        back_populates="author")


# UserLocation 모델 정의
class UserLocation(Base):
    __tablename__ = "user_location"  # 테이블 이름 지정

    id: Mapped[int] = mapped_column(Integer, primary_key=True,
                                    autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("user.id"))
    lat: Mapped[float] = mapped_column(Float, nullable=False)
    lng: Mapped[float] = mapped_column(Float, nullable=False)

    # 관계 설정
    user: Mapped["User"] = relationship("User", back_populates="locations")


class UserFCMToken(Base):
    __tablename__ = "user_fcm_token"

    id: Mapped[int] = mapped_column(Integer, primary_key=True,
                                    autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("user.id"))
    fcm_token: Mapped[str] = mapped_column(String(length=255), nullable=False)

    user: Mapped["User"] = relationship("User", back_populates="fcm_token")
