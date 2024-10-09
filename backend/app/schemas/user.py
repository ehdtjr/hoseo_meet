from datetime import datetime
from typing import Optional

from fastapi_users import schemas


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
