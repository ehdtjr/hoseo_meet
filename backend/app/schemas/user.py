import uuid
from datetime import datetime
from typing import Optional

from fastapi_users import schemas

from app.models.user import GenderEnum


class UserRead(schemas.BaseUser[uuid.UUID]):
    name: str
    gender: GenderEnum
    profile: Optional[str] = None
    created_at: datetime


class UserCreate(schemas.BaseUserCreate):
    name: str
    gender: GenderEnum
    profile: Optional[str] = None
    created_at: Optional[datetime] = None


class UserUpdate(schemas.BaseUserUpdate):
    name: Optional[str] = None
    gender: Optional[GenderEnum] = None
    profile: Optional[str] = None
