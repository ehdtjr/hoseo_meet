from datetime import datetime
from typing import Optional

from fastapi_users import schemas
from pydantic import BaseModel, ConfigDict, Field


class UserRead(schemas.BaseUser):
    id: int
    name: str
    gender: str
    profile: Optional[str] = None
    created_at: datetime


class UserPublicRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    profile: Optional[str] = None


class UserCreate(schemas.BaseUserCreate):
    name: str
    gender: str
    profile: Optional[str] = None


class UserUpdate(schemas.BaseUserUpdate):
    id: int
    name: Optional[str] = None
    profile: Optional[str] = None


class UserFCMTokenRequest(BaseModel):
    fcm_token: str


class UserFCMTokenBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    fcm_token: str


class UserFCMTokenCreate(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: int
    fcm_token: str

class KakaoUserUpdate(BaseModel):  # 어떨때 BaseModel, 어떨때 schemas.BaseUserUpdate?
    name: Optional[str] = None
    gender: Optional[str] = None  # 추가

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class UserReportBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: Optional[int] = None
    reporter_user_id: Optional[int] = None
    reported_user_id: Optional[int] = None
    reason: Optional[str] = None

    created_at: Optional[datetime] = None

class UserReportRequest(UserReportBase):
    reported_user_id: int
    reason: str = Field(..., max_length=500, description="신고 사유 (최대 500자)")

class UserReportCreate(UserReportBase):
    reporter_user_id: int
    reported_user_id: int
    reason: str = Field(..., max_length=500, description="신고 사유 (최대 500자)")

