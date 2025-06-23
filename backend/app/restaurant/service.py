from typing import Protocol, Optional, List

from fastapi import Depends, UploadFile
from shapely import wkb
from shapely.geometry.point import Point
from geoalchemy2.shape import from_shape
from sqlalchemy.ext.asyncio.session import AsyncSession

from app.core.exceptions import NotFoundException, InvalidImageFormatException
from app.core.s3 import S3Manager, get_s3_manager
from app.restaurant.crud import (
    RestaurantPostCRUDProtocol,
    RestaurantPostVersionCRUDProtocol,
    get_restaurant_post_crud,
    get_restaurant_post_version_crud, RestaurantPostImageCRUDProtocol,
    get_restaurant_post_image_crud, RestaurantPostImageSetVersionCRUD,
    get_restaurant_post_image_set_version_crud,
)
from app.restaurant.schemas import (
    RestaurantPostCreate,
    RestaurantPostBase,
    RestaurantPostVersionCreate,
    RestaurantPostUpdate,
    RestaurantPostVersionBase,
    Location, RestaurantPostImageCreate, RestaurantPostImageBase,
    RestaurantListItem, RestaurantPostImageSetVersionCreate,
    RestaurantPostDetail,
)
from app.utils.s3 import generate_s3_key


class RestaurantPostServiceProtocol(Protocol):
    async def create(self, db: AsyncSession, obj_in: RestaurantPostCreate) -> RestaurantPostBase: ...
    async def update(self, db: AsyncSession, obj_in: RestaurantPostUpdate) -> RestaurantPostBase: ...
    async def rollback(self, db: AsyncSession, version_id: int) -> Optional[RestaurantPostBase]: ...
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
    async def detail(
        self,
        db: AsyncSession,
        post_id: int,
        user_id: int,
        user_lat: Optional[float] = None,
        user_lon: Optional[float] = None,
    ) -> Optional[RestaurantPostDetail]:
        ...

class RestaurantPostService(RestaurantPostServiceProtocol):
    def __init__(
        self,
        restaurant_post_crud: RestaurantPostCRUDProtocol,
        restaurant_post_version_crud: RestaurantPostVersionCRUDProtocol,
        restaurant_post_image_crud: RestaurantPostImageCRUDProtocol,
    ):
        self.restaurant_post_crud = restaurant_post_crud
        self.restaurant_post_version_crud = restaurant_post_version_crud
        self.restaurant_post_image_crud = restaurant_post_image_crud

    async def _create_version(
            self, db: AsyncSession, post: RestaurantPostBase
    ) -> None:
        version_data = RestaurantPostVersionCreate(
            post_id=post.id,
            editor_id=post.editor_id,
            name=post.name,
            address=post.address,
            location=post.location,
        )
        await self.restaurant_post_version_crud.create(db=db,
                                                       obj_in=version_data)

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
        restaurant_post = await self.restaurant_post_crud.list(
            db=db,
            user_id=user_id,
            user_lat=user_lat,
            user_lon=user_lon,
            skip=skip,
            limit=limit,
            hearted_only=hearted_only,
        )

        if not restaurant_post:
            return []

        post_ids = [post.id for post in restaurant_post]
        image_map = await self.restaurant_post_image_crud.list_by_post_ids(
            db=db, post_ids=post_ids, limit_per_post=5
        )

        result: List[RestaurantListItem] = []

        for post in restaurant_post:
            images = image_map.get(post.id, [])
            result.append(
                RestaurantListItem(
                    id=post.id,
                    name=post.name,
                    address=post.address,
                    comment=post.comment,
                    distance=post.distance,
                    location=Location(
                        latitude=post.location.latitude,
                        longitude=post.location.longitude
                    ),
                    avg_rating=post.avg_rating,
                    review_count=post.review_count,
                    is_hearted=post.is_hearted,
                    images=[img.image for img in images]
                )
            )
        return result

    async def detail(
        self,
        db: AsyncSession,
        post_id: int,
        user_id: int,
        user_lat: Optional[float] = None,
        user_lon: Optional[float] = None,
    ) -> Optional[RestaurantPostDetail]:
        post_detail = await self.restaurant_post_crud.get_detail(
            db=db,
            post_id=post_id,
            user_id=user_id,
            user_lat=user_lat,
            user_lon=user_lon,
        )

        if not post_detail:
            raise NotFoundException()

        # 이미지 조회 후 주입
        images = await self.restaurant_post_image_crud.list_by_restaurant_id(
            db=db, restaurant_id=post_id, limit=5
        )
        post_detail.images = [img.image for img in images]

        return post_detail


def get_restaurant_post_service(
    restaurant_post_crud: RestaurantPostCRUDProtocol = Depends(get_restaurant_post_crud),
    restaurant_post_version_crud: RestaurantPostVersionCRUDProtocol = Depends(get_restaurant_post_version_crud),
    restaurant_post_image_crud: RestaurantPostImageCRUDProtocol = Depends(get_restaurant_post_image_crud)
) -> RestaurantPostServiceProtocol:
    return RestaurantPostService(
        restaurant_post_crud=restaurant_post_crud,
        restaurant_post_version_crud=restaurant_post_version_crud,
        restaurant_post_image_crud=restaurant_post_image_crud,
    )

class RestaurantPostImageServiceProtocol(Protocol):
    async def create(
        self,
        db: AsyncSession,
        image: UploadFile,
        post_id: int,
        editor_id: int,
    ) -> RestaurantPostImageBase:   ...

    async def update_image(self, db: AsyncSession, image_id: int, new_image_url: str, editor_id: int) -> RestaurantPostImageBase: ...
    async def delete(self, db: AsyncSession, image_id: int, user_id: int): ...
    async def rollback(self, db: AsyncSession, version_id: int, editor_id: int): ...

class RestaurantPostImageService(RestaurantPostImageServiceProtocol):
    def __init__(
        self,
        image_crud: RestaurantPostImageCRUDProtocol,
        image_set_version_crud: RestaurantPostImageSetVersionCRUD,
        s3_manager: S3Manager
    ):
        self.image_crud = image_crud
        self.image_set_version_crud = image_set_version_crud
        self.s3_manager = s3_manager

    async def _upload_image(self, upload_image: UploadFile) -> str:
        allowed_types = {"image/jpeg", "image/png", "image/webp"}
        if upload_image.content_type not in allowed_types:
            raise InvalidImageFormatException()

        unique_url = generate_s3_key(
            f"restaurant_post/{upload_image.filename}", "restaurant.webp"
        )
        return await self.s3_manager.upload_file(
            file=upload_image, destination_path=unique_url)

    async def create(
        self,
        db: AsyncSession,
        image: UploadFile,
        post_id: int,
        editor_id: int,
    ) -> RestaurantPostImageBase:

        image_url = await self._upload_image(upload_image=image)

        restaurant_post = RestaurantPostImageCreate(
            post_id=post_id,
            editor_id=editor_id,
            image=image_url
        )
        image = await self.image_crud.create(db, obj_in=restaurant_post)

        await self._save_image_set_version(db, post_id=post_id, editor_id=editor_id)

        return image

    async def delete(self, db: AsyncSession, image_id: int, user_id: int):
        image = await self.image_crud.get(db, id=image_id)
        if not image:
            raise NotFoundException()

        post_id = image.post_id
        editor_id = user_id

        await self.image_crud.delete(db, id=image_id)
        await self._save_image_set_version(db, post_id=post_id,
                                           editor_id=editor_id)

    async def _save_image_set_version(self, db: AsyncSession, post_id: int, editor_id: int):
        image_list = await self.image_crud.list_by_restaurant_id(db, restaurant_id=post_id)
        image_set_version = RestaurantPostImageSetVersionCreate(
            post_id=post_id,
            editor_id=editor_id,
            image_urls=[img.image for img in image_list]
        )
        await self.image_set_version_crud.create_version(db, image_set_version)

    async def rollback(self, db: AsyncSession, version_id: int, editor_id: int):
        version = await self.image_set_version_crud.get(db, id=version_id)
        if not version:
            raise NotFoundException()

        post_id = version.post_id

        current_images = await self.image_crud.list_by_restaurant_id(db,
                                                                     restaurant_id=post_id)
        current_image_ids = [img.id for img in current_images]
        if current_image_ids:
            await self.image_crud.delete_by_ids(db, current_image_ids)

        new_images = [RestaurantPostImageCreate(post_id=post_id, image=url,
                                                editor_id=editor_id) for url in
                      version.image_urls]
        await self.image_crud.bulk_create(db, new_images)

        await self._save_image_set_version(db, post_id=post_id,
                                           editor_id=editor_id)


def get_restaurant_post_image_service(
    image_crud: RestaurantPostImageCRUDProtocol = Depends(get_restaurant_post_image_crud),
    image_set_version_crud: RestaurantPostImageSetVersionCRUD = Depends(get_restaurant_post_image_set_version_crud),
    s3_manager: S3Manager = Depends(get_s3_manager)
) -> RestaurantPostImageServiceProtocol:
    return RestaurantPostImageService(
        image_crud=image_crud,
        image_set_version_crud=image_set_version_crud,
        s3_manager=s3_manager
    )
