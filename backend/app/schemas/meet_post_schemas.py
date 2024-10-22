from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.meet_post import MeetPostType


class MeetPostBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    type: MeetPostType
    author_id: int
    title: str
    content: str
    page_views: int = Field(default=0)
    created_at: datetime
    max_people: int = Field(..., ge=1, le=50)

class MeetPostCreate(BaseModel):
    model_config =  ConfigDict(from_attributes=True)

    title: str
    author_id: int
    title: str
    type: MeetPostType
    content: str
    max_people: int = Field(..., ge=1, le=50)


