from typing import Protocol, Optional, List

from geoalchemy2.shape import from_shape
from geoalchemy2.types import Geometry
from shapely.geometry import Point
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased
from sqlalchemy.sql.elements import and_
from sqlalchemy.sql.expression import bindparam, cast
from sqlalchemy.sql.sqltypes import Boolean

from app.crud.base import CRUDBase
from app.restaurant.model import RestaurantPost, RestaurantPostVersion, \
    RestaurantReview, RestaurantHeart
from app.restaurant.schemas import (
    RestaurantPostBase,
    RestaurantPostCreate,
    RestaurantPostVersionBase,
    RestaurantPostVersionCreate, RestaurantPostUpdate, RestaurantListItem,
    Location
)


class RestaurantPostCRUDProtocol(Protocol):
    async def create(self, db: AsyncSession, obj_in: RestaurantPostCreate) -> RestaurantPostBase: ...
    async def get(self, db: AsyncSession, id: int) -> RestaurantPostBase: ...
    async def update(self, db: AsyncSession, obj_in: RestaurantPostUpdate) -> RestaurantPostBase: ...
    async def list(
            self,
            db: AsyncSession,
            user_id: int,
            user_lat: float,
            user_lon: float,
            skip: int = 0,
            limit: int = 10,
            hearted_only: bool = False
    ) -> Optional[List[RestaurantListItem]]:
        ...

class RestaurantPostCRUD(CRUDBase[RestaurantPost, RestaurantPostBase], RestaurantPostCRUDProtocol):
    def __init__(self):
        super().__init__(RestaurantPost, RestaurantPostBase)

    async def create(self, db: AsyncSession, obj_in: RestaurantPostCreate) -> RestaurantPostBase:
        point = from_shape(
            Point(obj_in.location.longitude, obj_in.location.latitude),
            srid=4326)

        post = RestaurantPost(
            name=obj_in.name,
            address=obj_in.address,
            location=point,
            editor_id=obj_in.editor_id,
        )
        db.add(post)
        await db.commit()
        await db.refresh(post)
        return self.schema.model_validate(post, from_attributes=True)

    async def get(self, db: AsyncSession, id: int) -> RestaurantPostBase:
        return await super().get(db, id)

    async def update(
            self,
            db: AsyncSession,
            obj_in: RestaurantPostUpdate
    ) -> RestaurantPostBase:
        db_obj = await db.get(self.model, obj_in.id)
        update_data = obj_in.model_dump(exclude_unset=True)

        for field, value in update_data.items():
            if field == "location":
                if isinstance(value, dict):
                    longitude = value["longitude"]
                    latitude = value["latitude"]
                else:  # Pydantic 객체인 경우
                    longitude = value.longitude
                    latitude = value.latitude

                value = from_shape(Point(longitude, latitude), srid=4326)

            setattr(db_obj, field, value)

        await db.commit()
        await db.refresh(db_obj)
        return self.schema.model_validate(db_obj, from_attributes=True)

    async def list(
            self,
            db: AsyncSession,
            user_id: int,
            user_lat: float,
            user_lon: float,
            skip: int = 0,
            limit: int = 10,
            hearted_only: bool = False
    ) -> Optional[List[RestaurantListItem]]:

        distance_expr = func.ST_Distance(
            RestaurantPost.location,
            func.ST_SetSRID(func.ST_MakePoint(user_lon, user_lat), 4326)
        ).label("distance")

        longitude_expr = func.ST_X(
            RestaurantPost.location.cast(Geometry)).label("longitude")
        latitude_expr = func.ST_Y(RestaurantPost.location.cast(Geometry)).label(
            "latitude")

        avg_rating = func.coalesce(func.avg(RestaurantReview.rating), 0).label(
            "avg_rating")
        review_count = func.count(RestaurantReview.id).label("review_count")

        heart_alias = aliased(RestaurantHeart)

        join_condition = and_(
            RestaurantPost.id == heart_alias.post_id,
            bindparam("user_id") == heart_alias.user_id
        )

        is_hearted_expr = cast(
            func.count(heart_alias.id).filter(
                heart_alias.user_id == bindparam("user_id")
            ) > 0,
            Boolean
        ).label("is_hearted")

        stmt = (
            select(
                RestaurantPost,
                distance_expr,
                latitude_expr,
                longitude_expr,
                avg_rating,
                review_count,
                is_hearted_expr
            )
            .outerjoin(RestaurantReview,
                       RestaurantReview.post_id == RestaurantPost.id)
            .outerjoin(heart_alias, join_condition)
            .group_by(RestaurantPost.id, latitude_expr, longitude_expr)
        )

        if hearted_only:
            stmt = stmt.having(func.count(heart_alias.id) > 0)

        stmt = stmt.order_by(distance_expr).offset(skip).limit(limit)

        result = await db.execute(stmt.params(user_id=user_id))
        rows = result.all()

        restaurants = [
            RestaurantListItem(
                id=row[0].id,
                name=row[0].name,
                address=row[0].address,
                distance=row[1],
                location=Location(latitude=row[2], longitude=row[3]),
                avg_rating=float(row[4]),
                review_count=row[5],
                is_hearted=row[6]
            )
            for row in rows
        ]
        return restaurants

def get_restaurant_post_crud() -> RestaurantPostCRUDProtocol:
    return RestaurantPostCRUD()

class RestaurantPostVersionCRUDProtocol(Protocol):
    async def create(
        self, db: AsyncSession, obj_in: RestaurantPostVersionCreate
    ) -> RestaurantPostVersionBase: ...
    async def get(
        self, db: AsyncSession, id: int) -> Optional[RestaurantPostVersionBase]: ...
    async def get_latest_by_post_id(
        self, db: AsyncSession, post_id: int
    ) -> Optional[RestaurantPostVersionBase]: ...


class RestaurantPostVersionCRUD(
    CRUDBase[RestaurantPostVersion, RestaurantPostVersionBase],
    RestaurantPostVersionCRUDProtocol
):
    def __init__(self):
        super().__init__(RestaurantPostVersion, RestaurantPostVersionBase)

    async def create(
            self, db: AsyncSession, obj_in: RestaurantPostVersionCreate
    ) -> RestaurantPostVersionBase:
        result = await db.execute(
            select(self.model)
            .where(self.model.post_id == obj_in.post_id)
            .order_by(self.model.version.desc())
            .limit(1)
        )
        latest_version = result.scalar_one_or_none()
        next_version = (latest_version.version + 1) if latest_version else 1

        point = from_shape(
            Point(obj_in.location.longitude, obj_in.location.latitude),
            srid=4326
        )

        version_obj = RestaurantPostVersion(
            post_id=obj_in.post_id,
            version=next_version,
            name=obj_in.name,
            address=obj_in.address,
            location=point,
            editor_id=obj_in.editor_id
        )

        db.add(version_obj)
        await db.commit()
        await db.refresh(version_obj)
        return self.schema.model_validate(version_obj, from_attributes=True)

    async def get(self, db: AsyncSession, id: int) -> Optional[
        RestaurantPostVersionBase]:
        return await super().get(db, id)

    async def get_latest_by_post_id(
            self, db: AsyncSession, post_id: int
    ) -> Optional[RestaurantPostVersionBase]:
        result = await db.execute(
            select(self.model)
            .where(self.model.post_id == post_id)
            .order_by(self.model.version.desc())
            .limit(1)
        )
        latest = result.scalar_one_or_none()
        if not latest:
            return None
        return self.schema.model_validate(latest, from_attributes=True)

    async def get_versions_by_post_id(
            self,
            db: AsyncSession,
            post_id: int,
            skip: int = 0,
            limit: int = 10
    ) -> List[RestaurantPostVersionBase]:
        result = await db.execute(
            select(self.model)
            .where(self.model.post_id == post_id)
            .order_by(self.model.version.desc())
            .offset(skip)
            .limit(limit)
        )
        versions = result.scalars().all()
        return [
            self.schema.model_validate(v, from_attributes=True) for v in
            versions
        ]


def get_restaurant_post_version_crud() -> RestaurantPostVersionCRUDProtocol:
    return RestaurantPostVersionCRUD()
