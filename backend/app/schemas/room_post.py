from datetime import datetime
from typing import Optional, List

from app.utils.date import convert_to_local_time
from fastapi import UploadFile
from pydantic import BaseModel, Field, computed_field, ConfigDict


class RoomPostBase(BaseModel):
    model_config = ConfigDict(
        from_attributes=True
    )  # SQLAlchemy 모델에서 값을 가져올 때 필요

    id: int
    name: str
    address: str
    contact: Optional[str] = None
    price: Optional[str] = None
    fee: Optional[str] = None
    options: Optional[str] = None
    gas_type: Optional[str] = None
    comment: Optional[str] = None
    place: str
    latitude: float
    longitude: float


class RoomPostListResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str

    reviews_count: int = 0
    avg_rating: float = 0.0
    distance: float = 0.0

    images: Optional[List[str]] = []


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
    latitude: float
    longitude: float

    images: Optional[List[str]] = []


# 작성자(public) 정보 예시
class UserPublicRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    name: str
    profile: Optional[str] = None


class RoomReviewResponse(BaseModel):
    id: int
    room_id: int
    content: str
    rating: float
    created_at: datetime

    author: UserPublicRead
    images: Optional[List[str]] = []

    model_config = ConfigDict(from_attributes=True)


class RoomReviewListResponse(RoomReviewResponse):
    @computed_field
    @property
    def short_content(self) -> str:
        lines = self.content.splitlines()
        if len(lines) > 3:
            return "\n".join(lines[:3]) + "..."
        return self.content


class RoomImageBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    review_id: Optional[int] = None
    room_id: Optional[int] = None
    image: str
    created_at: datetime


class RoomImageCreate(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    review_id: Optional[int] = None
    room_id: Optional[int] = None
    image: str


class RoomImagesList(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    room_id: int
    images: List[str]


class RoomImageResponse(RoomImageBase):
    pass


class RoomImageListResponse(RoomImageResponse):
    pass
