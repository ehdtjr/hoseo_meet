from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from enum import Enum as PyEnum


class MeetPostType(PyEnum):
    """
    모임, 배달, 택시 카풀
    """
    MEET = "meet"
    DELIVERY = "delivery"
    TAXI = "taxi"
    CARPOOL = "carpool"


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
