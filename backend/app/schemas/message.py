from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict

from app.models.message import MessageType


class MessageBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    sender_id: int
    type: MessageType
    recipient_id: int
    content: str
    client_message_id: Optional[str] = None
    rendered_content: Optional[str] = None
    date_sent: datetime


class MessageCreate(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    sender_id: int
    type: MessageType
    recipient_id: int
    content: str
    client_message_id: Optional[str] = None
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
    stream_id: int
    unread_count: int


class MessageSendResponse(BaseModel):
    message: str = "Message saved successfully"
    message_id: int
    client_message_id: str
    storage_status: Literal["saved"] = "saved"
    delivery_status: Literal["pending", "completed"]
    duplicate: bool = False

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
