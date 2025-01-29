from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict

from app.schemas.common import PostType


class StreamBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    type: str
    date_created: Optional[datetime] = None
    creator_id: Optional[int] = None
    recipient_id: Optional[int] = None


class StreamCreate(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    name: str
    type: PostType
    creator_id: int


class StreamRequest(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    name: str
    type: str


class StreamRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    type:str
    creator_id: Optional[int] = None
    date_created: Optional[datetime] = None


class SubscriptionBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    recipient_id: int
    active: bool
    is_user_active: bool
    is_muted: bool


class SubscriptionRead(SubscriptionBase):
    pass


class SubscriptionCreate(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: int
    recipient_id: int
    active: bool = True
    is_user_active: bool = True
    is_muted: bool = False


class SubscriptionRequest(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    stream_id: int