from datetime import datetime
from typing import Optional, List, Dict

from geoalchemy2.types import WKBElement
from shapely import wkb
from pydantic import BaseModel, ConfigDict, field_serializer


class Location(BaseModel):
    latitude: float
    longitude: float


class RestaurantPostBase(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
        arbitrary_types_allowed=True,
    )

    id: int
    editor_id: int
    name: str
    address: Optional[str] = None
    comment: Optional[str] = None
    contact: Optional[str] = None
    business_hours: Optional[str] = None
    location: WKBElement

    @field_serializer("location", when_used="always")
    def serialize_location(self, location: WKBElement) -> dict:
        point = wkb.loads(bytes(location.data))
        return {
            "latitude": point.y,
            "longitude": point.x
        }


class RestaurantPostCreate(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    editor_id: int
    name: str
    address: Optional[str] = None
    comment: Optional[str] = None
    contact: Optional[str] = None
    business_hours: Optional[str] = None
    location: Location


class RestaurantPostRequest(BaseModel):
    name: str
    address: Optional[str] = None
    contact: Optional[str] = None
    business_hours: Optional[str] = None
    location: Location

class RestaurantListItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    address: Optional[str] = None
    comment: Optional[str] = None
    distance: float
    location: Location
    avg_rating: float
    review_count: int
    is_hearted: bool
    images: Optional[List[str]] = []

class RestaurantPostDetail(RestaurantListItem):
    contact: Optional[str] = None
    business_hours: Optional[str] = None
    review_rating_counts: Dict[int, int] = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}

class RestaurantPostUpdate(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    editor_id: Optional[int] =None
    name: str
    address: Optional[str] = None
    comment: Optional[str] = None
    contact: Optional[str] = None
    business_hours: Optional[str] = None
    location: Location


class RestaurantPostVersionBase(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
        arbitrary_types_allowed=True,
    )

    id: int
    editor_id: int
    post_id: int
    version: int
    name: str
    address: str
    contact: Optional[str] = None
    business_hours: Optional[str] = None
    location: WKBElement
    created_at: datetime

    @field_serializer("location", when_used="always")
    def serialize_location(self, location: WKBElement) -> dict:
        point = wkb.loads(bytes(location.data))
        return {
            "latitude": point.y,
            "longitude": point.x
        }

class RestaurantPostVersionCreate(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
        arbitrary_types_allowed=True,
    )

    editor_id: int
    post_id: int
    version: Optional[int] = None
    name: str
    address: str
    contact: Optional[str] = None
    business_hours: Optional[str] = None
    location: WKBElement


    @field_serializer("location", when_used="always")
    def serialize_location(self, location: WKBElement) -> dict:
        point = wkb.loads(bytes(location.data))
        return {
            "latitude": point.y,
            "longitude": point.x
        }

class RestaurantPostImageBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    post_id: int
    image: str
    editor_id: int


class RestaurantPostImageCreate(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    post_id: int
    image: str
    editor_id: int

class RestaurantPostImageSetVersionBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    post_id: int
    image_urls: List[str]
    version: int
    created_at: datetime
    editor_id: int

class RestaurantPostImageSetVersionCreate(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    post_id: int
    image_urls: List[str]
    version: Optional[int] = None  # 새로 생성 시 자동 증가를 위해 생략 가능
    editor_id: int

class MenuItem(BaseModel):
    name: str
    price: int
    image: Optional[str] = None


class RestaurantMenuBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    editor_id: int
    post_id: int
    name: str
    price: int
    image: Optional[str] = None


class RestaurantMenuCreate(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    editor_id: int
    post_id: int
    name: str
    price: int
    image: Optional[str] = None


class RestaurantMenuSetVersionBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    post_id: int
    version: int
    menus: List[MenuItem]
    editor_id: int
    created_at: datetime


class RestaurantMenuSetVersionCreate(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    post_id: int
    menus: List[MenuItem]
    editor_id: int
    version: Optional[int] = None  # 자동 증가 고려