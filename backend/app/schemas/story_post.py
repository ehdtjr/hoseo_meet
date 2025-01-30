from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field, ConfigDict


class TextPosition(BaseModel):
    x: float = Field(..., description="Normalized X coordinate between 0 and 1")
    y: float = Field(..., description="Normalized Y coordinate between 0 and 1")


class FontStyle(BaseModel):
    name: str = Field(..., min_length=1, max_length=50, description="Font name")
    size: int = Field(..., ge=1, le=100, description="Font size")
    bold: Optional[bool] = False  # Optional field with a default value
    color: str = Field()


class TextOverlay(BaseModel):
    text: str = Field(..., min_length=1, max_length=200, description="Overlay text")
    position: TextPosition = Field(..., description="Position of the text overlay")
    font_style: FontStyle = Field(..., description="Font style configuration")

class StoryPostBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    author_id: int
    stream_id: int
    text_overlay: TextOverlay
    image_url: str
    created_at: datetime
    expires_at: datetime

class StoryPostCreate(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    author_id: int
    stream_id: int
    image_url: str
    text_overlay: TextOverlay = Field(..., description="Text overlay")

class StoryPostRequest(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    image_url: str
    text_overlay: TextOverlay = Field(..., description="Text overlay")

class StoryPostResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    author_id: int
    text_overlay: TextOverlay = Field(..., description="Text overlay")
    image_url: str
    is_subscribed: bool
    created_at: datetime