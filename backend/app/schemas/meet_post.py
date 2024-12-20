from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.user import UserRead, UserPublicRead

MeetPostType = Literal["meet", "delivery", "taxi", "carpool"]

class MeetPostBase(BaseModel):
    model_config = ConfigDict(use_enum_values=True, from_attributes=True)

    id: int
    title: str
    type: MeetPostType
    author_id: int
    stream_id: int
    content: str
    page_views: int = Field(default=0)
    created_at: datetime
    max_people: int = Field(..., ge=1, le=50)


class MeetPostCreate(BaseModel):
    model_config = ConfigDict(use_enum_values=True, from_attributes=True)

    title: str
    author_id: int
    stream_id: int
    type: MeetPostType
    content: str
    max_people: int = Field(..., ge=1, le=50)


class MeetPostRequest(BaseModel):
    model_config = ConfigDict(use_enum_values=True, from_attributes=True)

    title: str
    type: MeetPostType
    content: str
    max_people: int = Field(..., ge=1, le=50)

class MeetPostResponse(BaseModel):
    model_config = ConfigDict(use_enum_values=True, from_attributes=True)

    id: int
    title: str
    type: MeetPostType

    author: UserPublicRead
    stream_id: int
    content: str
    page_views: int = Field(default=0)
    created_at: datetime
    max_people: int = Field(..., ge=1, le=50)
    current_people: int
