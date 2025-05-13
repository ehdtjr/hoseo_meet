from datetime import datetime
from typing import Optional, List, Dict

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
    is_heart: bool = False


class RoomPostDetailResponse(RoomPostListResponse):
    address: Optional[str] = None
    contact: Optional[str] = None
    price: Optional[str] = None
    fee: Optional[str] = None
    options: Optional[str] = None
    gas_type: Optional[str] = None
    comment: Optional[str] = None
    review_rating_counts: Dict[int, int] = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}

    place: str

class RoomPostHeartBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: Optional[int] = None
    user_id: int
    room_id: int


class RoomReviewResponse(BaseModel):
    id: int
    room_id: int
    content: str
    rating: float
    created_at: datetime

    author: UserPublicRead
    images: Optional[List[str]]

    model_config = ConfigDict(from_attributes=True)

class RoomReviewImageBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    review_id: int
    room_id: int
    image: str
    created_at: datetime
