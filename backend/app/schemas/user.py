from datetime import datetime
from typing import Optional

from fastapi_users import schemas
from pydantic import BaseModel, ConfigDict


class UserRead(schemas.BaseUser):
    id: int
    name: str
    gender: str
    profile: Optional[str] = None
    is_online: bool
    created_at: datetime


class UserCreate(schemas.BaseUserCreate):
    name: str
    gender: str
    profile: Optional[str] = None


class UserUpdate(schemas.BaseUserUpdate):
    id: int
    name: Optional[str] = None
    profile: Optional[str] = None
    is_online: Optional[bool] = None


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
