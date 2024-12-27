from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict

from app.models.message import MessageType


class MessageBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    sender_id: int
    type: MessageType
    recipient_id: int
    content: str
    rendered_content: Optional[str] = None
    date_sent: datetime


class MessageCreate(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    sender_id: int
    type: MessageType
    recipient_id: int
    content: str
    rendered_content: Optional[str] = None


class MessageRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    sender_id: int
    recipient_id: int
    content: str
    rendered_content: Optional[str] = None
    date_sent: datetime

class MessageResponse(MessageBase):
    unread_count: int

class UserMessageBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    message_id: int
    is_read: Optional[bool] = False


class UserMessageCreate(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: int
    message_id: int
    is_read: Optional[bool] = False


class UpdateUserMessageFlagsRequest(BaseModel):
    anchor: str = "first_unread"
    stream_id: int
    num_before: int
    num_after: int

class LocationBase(BaseModel):
    lat: float
    lng: float