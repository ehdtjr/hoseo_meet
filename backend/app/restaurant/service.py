from typing import Protocol, Optional

from fastapi import Depends
from shapely import wkb
from shapely.geometry.point import Point
from sqlalchemy.ext.asyncio.session import AsyncSession

from app.core.exceptions import NotFoundException
from app.restaurant.crud import (
    RestaurantPostCRUDProtocol,
    RestaurantPostVersionCRUDProtocol,
    get_restaurant_post_crud,
    get_restaurant_post_version_crud,
)
from app.restaurant.schemas import (
    RestaurantPostCreate,
    RestaurantPostBase,
    RestaurantPostVersionCreate,
    RestaurantPostUpdate,
    RestaurantPostVersionBase,
    Location,
)


class RestaurantPostServiceProtocol(Protocol):
    async def create(self, db: AsyncSession, obj_in: RestaurantPostCreate) -> RestaurantPostBase: ...
    async def update(self, db: AsyncSession, obj_in: RestaurantPostUpdate) -> RestaurantPostBase: ...
    async def rollback(self, db: AsyncSession, version_id: int) -> Optional[RestaurantPostBase]: ...


class RestaurantPostService(RestaurantPostServiceProtocol):
    def __init__(
        self,
        restaurant_post_crud: RestaurantPostCRUDProtocol,
        restaurant_post_version_crud: RestaurantPostVersionCRUDProtocol,
    ):
        self.restaurant_post_crud = restaurant_post_crud
        self.restaurant_post_version_crud = restaurant_post_version_crud

    async def _create_version(
        self, db: AsyncSession, post: RestaurantPostBase
    ) -> None:
        point: Point = wkb.loads(bytes(post.location.data))
        location = Location(latitude=point.y, longitude=point.x)

        version_data = RestaurantPostVersionCreate(
            post_id=post.id,
            editor_id=post.editor_id,
            name=post.name,
            address=post.address,
            location=location
        )
        await self.restaurant_post_version_crud.create(db=db, obj_in=version_data)

    @staticmethod
    def _is_modified(
        post: RestaurantPostBase,
        version: RestaurantPostVersionBase
    ) -> bool:
        post_dict = post.model_dump(exclude={"id"})
        version_dict = version.model_dump(exclude={"id", "version", "created_at"})

        return any(
            post_dict.get(key) != version_dict.get(key)
            for key in post_dict.keys() & version_dict.keys()
        )

    async def create(
        self,
        db: AsyncSession,
        obj_in: RestaurantPostCreate,
    ) -> RestaurantPostBase:
        post = await self.restaurant_post_crud.create(db=db, obj_in=obj_in)
        await self._create_version(db, post)
        return post

    async def update(
        self,
        db: AsyncSession,
        obj_in: RestaurantPostUpdate,
    ) -> RestaurantPostBase:
        post = await self.restaurant_post_crud.update(db=db, obj_in=obj_in)
        version = await self.restaurant_post_version_crud.get_latest_by_post_id(
            db=db, post_id=post.id
        )
        if version is None or self._is_modified(post, version):
            await self._create_version(db, post)
        return post

    async def rollback(self, db: AsyncSession, version_id: int) -> Optional[
        RestaurantPostBase]:
        version: RestaurantPostVersionBase = await self.restaurant_post_version_crud.get(
            db=db, id=version_id)
        if not version:
            raise NotFoundException()

        current_post = await self.restaurant_post_crud.get(db=db,
                                                           id=version.post_id)
        if not current_post:
            raise NotFoundException()

        if not self._is_modified(current_post, version):
            return current_post

        point = wkb.loads(bytes(version.location.data))
        location = Location(latitude=point.y, longitude=point.x)

        update_data = RestaurantPostUpdate(
            id=version.post_id,
            editor_id=version.editor_id,
            name=version.name,
            address=version.address,
            location=location,
        )
        post = await self.restaurant_post_crud.update(db=db, obj_in=update_data)
        await self._create_version(db, post)
        return post


def get_restaurant_post_service(
    restaurant_post_crud: RestaurantPostCRUDProtocol = Depends(get_restaurant_post_crud),
    restaurant_post_version_crud: RestaurantPostVersionCRUDProtocol = Depends(get_restaurant_post_version_crud),
) -> RestaurantPostServiceProtocol:
    return RestaurantPostService(
        restaurant_post_crud=restaurant_post_crud,
        restaurant_post_version_crud=restaurant_post_version_crud,
    )
