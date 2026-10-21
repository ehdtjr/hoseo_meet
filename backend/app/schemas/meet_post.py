from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, computed_field

from app.schemas.common import PostType
from app.schemas.user import UserPublicRead


class MeetPostBase(BaseModel):
    model_config = ConfigDict(use_enum_values=True, from_attributes=True)

    id: int
    title: str
    type: PostType
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
    type: PostType
    content: str
    max_people: int = Field(..., ge=1, le=50)


class MeetPostRequest(BaseModel):
    model_config = ConfigDict(use_enum_values=True, from_attributes=True)

    title: str
    type: PostType
    content: str
    max_people: int = Field(..., ge=1, le=50)


class MeetPostResponse(BaseModel):
    id: int
    title: str
    type: str
    author: UserPublicRead
    stream_id: int
    content: str
    page_views: int = Field(default=0)
    created_at: datetime
    max_people: int = Field(..., ge=1, le=50)
    current_people: int
    is_subscribed: bool = False


class MeetPostListResponse(MeetPostResponse):
    @computed_field
    @property
    def short_content(self) -> str:
        lines = self.content.splitlines()
        if len(lines) > 10:
            return "\n".join(lines[:10]) + "..."
        return self.content