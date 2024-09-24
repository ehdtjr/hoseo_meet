import enum
import uuid
from fastapi_users.db import SQLAlchemyBaseUserTableUUID
from sqlalchemy import Column, String, DateTime, Enum, Float, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime

from sqlalchemy.orm import relationship

from app.core.db import Base


# GenderEnum 정의
class GenderEnum(enum.Enum):
    male = "male"
    female = "female"


# User 모델 정의
class User(SQLAlchemyBaseUserTableUUID, Base):
    __tablename__ = "user"

    name = Column(String, nullable=False)
    gender: Column[GenderEnum] = Column(Enum(GenderEnum), nullable=False)
    profile = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # 관계 설정
    meet_post = relationship("MeetPost", back_populates="author")


# UserLocation 모델 정의
class UserLocation(Base):
    __tablename__ = "user_location"  # 테이블 이름 지정

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    user_id = Column(
        UUID(as_uuid=True), ForeignKey("user.id"), nullable=False, index=True
    )
    lat = Column(Float, nullable=False)
    lng = Column(Float, nullable=False)
