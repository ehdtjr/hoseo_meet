from datetime import datetime
from typing import Optional, List

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
    address: str
    comment: Optional[str]
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
    address: str
    location: Location


class RestaurantPostRequest(BaseModel):
    name: str
    address: str
    location: Location

class RestaurantListItem(BaseModel):
    id: int
    name: str
    address: str
    distance: float
    location: Location
    avg_rating: float
    review_count: int
    is_hearted: bool
    images: Optional[List[str]] = []

class RestaurantPostUpdate(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    editor_id: Optional[int]
    name: str
    address: str
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
    model_config = ConfigDict(from_attributes=True)

    editor_id: int
    post_id: int
    name: str
    address: str
    location: Location
