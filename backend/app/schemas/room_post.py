from datetime import datetime
from typing import Optional, List

from app.utils.date import convert_to_local_time
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

    # 리뷰 개수
    reviews_count: int = 0
    # 평균 별점
    avg_rating: float = 0.0
    # 유저 위치 기준 거리 (미터/킬로미터 단위? 여기서는 편의상 float)
    distance: float = 0.0


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
    images: List[str] = []

    def dict(self, **kwargs):
        data = super().dict(**kwargs)
        if "created_at" in data:
            data["created_at"] = convert_to_local_time(data["created_at"], timezone="Asia/Seoul").isoformat()
        return data

    model_config = ConfigDict(from_attributes=True)


# class RoomReviewBase(BaseModel):
#     model_config = ConfigDict(from_attributes=True)

#     id: int
#     room_id: int
#     author_id: int
#     content: str
#     rating: float = Field(..., ge=0, le=5)
#     created_at: datetime


# class RoomReviewCreate(BaseModel):
#     model_config = ConfigDict(from_attributes=True)

#     room_id: int
#     author_id: int
#     content: str
#     rating: float = Field(..., ge=0, le=5)


# class RoomReviewRequest(BaseModel):
#     model_config = ConfigDict(from_attributes=True)

#     content: str
#     rating: float = Field(..., ge=0, le=5)


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


class RoomImageResponse(RoomImageBase):
    pass


class RoomImageListResponse(RoomImageResponse):
    pass
