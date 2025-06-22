from typing import Protocol, Optional, List, Dict, Any, Callable, Coroutine
from collections import defaultdict

from geoalchemy2.shape import from_shape
from geoalchemy2.types import Geometry
from shapely.geometry import Point
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased
from sqlalchemy.sql.elements import and_
from sqlalchemy.sql.expression import bindparam, cast, delete
from sqlalchemy.sql.sqltypes import Boolean

from app.crud.base import CRUDBase
from app.restaurant.model import RestaurantPost, RestaurantPostVersion, \
    RestaurantReview, RestaurantHeart, RestaurantPostImage, \
    RestaurantPostImageSetVersion

from app.restaurant.schemas import (
    RestaurantPostBase,
    RestaurantPostCreate,
    RestaurantPostVersionBase,
    RestaurantPostUpdate, RestaurantListItem,
    Location, RestaurantPostImageBase, RestaurantPostImageCreate,
    RestaurantPostVersionCreate, RestaurantPostImageSetVersionBase,
    RestaurantPostImageSetVersionCreate
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

class RestaurantPostImageCRUDProtocol(Protocol):
    async def create(self, db: AsyncSession, obj_in: RestaurantPostImageCreate) -> RestaurantPostImageBase:
        ...

    async def get(self, db: AsyncSession, id: int) -> Optional[RestaurantPostImageBase]:
        ...

    async def delete(self, db: AsyncSession, id: int) -> bool:
        ...

    async def list_by_restaurant_id(
        self,
        db: AsyncSession,
        restaurant_id: int,
        skip: int = 0,
        limit: int = 5
    ) -> Optional[List[RestaurantPostImageBase]]:
        ...

    async def list_by_post_ids(
        self,
        db: AsyncSession,
        post_ids: List[int],
        limit_per_post: int = 3
    ) -> Dict[int, List[RestaurantPostImageBase]]:
        ...

    async def delete_by_ids(self, db: AsyncSession, ids: List[int]) -> Callable[
        [], int]:
        ...

    async def bulk_create(self, db: AsyncSession,
                          objs_in: List[RestaurantPostImageCreate]) -> List[
        RestaurantPostImageBase]:
        ...

class RestaurantPostImageCRUD(
    CRUDBase[RestaurantPostImage, RestaurantPostImageBase],
    RestaurantPostImageCRUDProtocol
):
    def __init__(self):
        super().__init__(RestaurantPostImage, RestaurantPostImageBase)

    async def create(self, db: AsyncSession, obj_in: RestaurantPostImageCreate) -> RestaurantPostImageBase:
        return await super().create(db, obj_in)

    async def get(self, db: AsyncSession, id: int) -> Optional[RestaurantPostImageBase]:
        return await super().get(db, id)

    async def delete(self, db: AsyncSession, id: int) -> bool:
        return await super().delete(db, id)

    async def delete_by_ids(self, db: AsyncSession, ids: List[int]) -> Callable[
        [], int]:
        stmt = delete(self.model).where(self.model.id.in_(ids))
        result = await db.execute(stmt)
        await db.commit()
        return result.rowcount

    async def bulk_create(self, db: AsyncSession,
                          objs_in: List[RestaurantPostImageCreate]) -> List[
        RestaurantPostImageBase]:
        instances = [self.model(**obj.model_dump()) for obj in objs_in]
        db.add_all(instances)
        await db.commit()

        for instance in instances:
            await db.refresh(instance)

        return [self.schema.model_validate(i, from_attributes=True) for i in
                instances]

    async def list_by_restaurant_id(
        self,
        db: AsyncSession,
        restaurant_id: int,
        skip: int = 0,
        limit: int = 5
    ) -> Optional[List[RestaurantPostImageBase]]:
        stmt = (
            select(self.model)
            .where(self.model.post_id == restaurant_id)
            .offset(skip)
            .limit(limit)
        )
        result = await db.execute(stmt)
        images = result.scalars().all()
        return [
            self.schema.model_validate(image, from_attributes=True)
            for image in images
        ]
    async def list_by_post_ids(
        self,
        db: AsyncSession,
        post_ids: List[int],
        limit_per_post: int = 3
    ) -> Dict[int, List[RestaurantPostImageBase]]:
        if not post_ids:
            return {}

        stmt = (
            select(self.model)
            .where(self.model.post_id.in_(post_ids))
            .order_by(self.model.post_id, self.model.id.desc())
        )
        result = await db.execute(stmt)
        images = result.scalars().all()

        grouped: Dict[int, List[RestaurantPostImageBase]] = defaultdict(list)
        for img in images:
            if len(grouped[img.post_id]) < limit_per_post:
                grouped[img.post_id].append(
                    self.schema.model_validate(img, from_attributes=True)
                )
        return grouped

def get_restaurant_post_image_crud() -> RestaurantPostImageCRUDProtocol:
    return RestaurantPostImageCRUD()


class RestaurantPostImageSetVersionCRUD(
    CRUDBase[RestaurantPostImageSetVersion, RestaurantPostImageSetVersionBase]
):
    def __init__(self):
        super().__init__(RestaurantPostImageSetVersion, RestaurantPostImageSetVersionBase)

    async def create_version(
        self, db: AsyncSession, obj_in: RestaurantPostImageSetVersionCreate
    ) -> RestaurantPostImageSetVersionBase:
        result = await db.execute(
            select(self.model)
            .where(self.model.post_id == obj_in.post_id)
            .order_by(self.model.version.desc())
            .limit(1)
        )
        latest = result.scalar_one_or_none()
        next_version = (latest.version + 1) if latest else 1

        version_obj = self.model(
            post_id=obj_in.post_id,
            version=next_version,
            image_urls=obj_in.image_urls,
            editor_id=obj_in.editor_id
        )
        db.add(version_obj)
        await db.commit()
        await db.refresh(version_obj)
        return self.schema.model_validate(version_obj, from_attributes=True)

    async def get_latest_by_post_id(
        self, db: AsyncSession, post_id: int
    ) -> Optional[RestaurantPostImageSetVersionBase]:
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
            self, db: AsyncSession, post_id: int, skip: int = 0, limit: int = 10
    ) -> List[RestaurantPostImageSetVersionBase]:
        result = await db.execute(
            select(self.model)
            .where(self.model.post_id == post_id)
            .order_by(self.model.version.desc())
            .offset(skip)
            .limit(limit)
        )
        versions = result.scalars().all()
        return [self.schema.model_validate(v, from_attributes=True) for v in
                versions]

def get_restaurant_post_image_set_version_crud() -> RestaurantPostImageSetVersionCRUD:
    return RestaurantPostImageSetVersionCRUD()