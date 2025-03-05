from datetime import datetime
from typing import Optional, List

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.user import UserPublicRead


class RoomPostListResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    reviews_count: int = 0
    avg_rating: float = 0.0
    distance: float = 0.0
    images: Optional[List[str]]


class RoomPostDetailResponse(RoomPostListResponse):
    # 상속받았으므로 id, name, reviews_count, avg_rating, distance 포함
    address: Optional[str] = None
    contact: Optional[str] = None
    price: Optional[str] = None
    fee: Optional[str] = None
    options: Optional[str] = None
    gas_type: Optional[str] = None
    comment: Optional[str] = None
    place: str


class RoomReviewResponse(BaseModel):
    id: int
    room_id: int
    content: str
    rating: float
    created_at: datetime

    author: UserPublicRead
    images: Optional[List[str]]

    model_config = ConfigDict(from_attributes=True)


class RoomImagesList(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    room_id: int
    images: List[str]

