from geoalchemy2 import WKBElement, Geography
from pygments.token import String
from sqlalchemy import Integer
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class RestaurantPost(Base):

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    address: Mapped[str] = mapped_column(String, nullable=False)
    comment: Mapped[str] = mapped_column(String, nullable=False)
    location: Mapped[WKBElement] = mapped_column(
        Geography(geometry_type='POINT', srid=4326, spatial_index=True),
        nullable=False
    )


class RestaurantPostVersion(Base):
    ...

class RestaurantMenu(Base):
    ...

class RestaurantMenuVersion(Base):
    ...

class RestaurantPostImage(Base):
    ...

class RestaurantReviewImage(Base):
    ...

class RestaurantHeart(Base):
    ...