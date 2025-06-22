from typing import List

from fastapi import APIRouter, Depends, UploadFile, File
from mypy.binder import Optional
from sqlalchemy.ext.asyncio.session import AsyncSession

from app.core.db import get_async_session
from app.core.security import current_active_user
from app.models import User
from app.restaurant.crud import RestaurantPostVersionCRUD, \
    get_restaurant_post_version_crud, RestaurantPostImageCRUDProtocol, \
    get_restaurant_post_image_crud, get_restaurant_post_image_set_version_crud
from app.restaurant.schemas import RestaurantPostCreate, RestaurantPostRequest, \
    RestaurantPostUpdate, RestaurantListItem, RestaurantPostVersionBase, \
    RestaurantPostImageBase, RestaurantPostImageSetVersionBase
from app.restaurant.service import RestaurantPostServiceProtocol, \
    get_restaurant_post_service, RestaurantPostService, \
    get_restaurant_post_image_service, RestaurantPostImageServiceProtocol

router = APIRouter()

@router.post("/create")
async def create_restaurant(
    restaurant_request: RestaurantPostRequest,
    db: AsyncSession = Depends(get_async_session),
    user: User = Depends(current_active_user),
    restaurant_service: RestaurantPostServiceProtocol =\
         Depends(get_restaurant_post_service)
):
    restaurant = RestaurantPostCreate(
        name=restaurant_request.name,
        editor_id=user.id,
        address=restaurant_request.address,
        location=restaurant_request.location,
    )
    return await restaurant_service.create(
        db=db,
        obj_in=restaurant
    )

@router.get("/list", response_model=Optional[List[RestaurantListItem]])
async def get_restaurants_list(
    user_lat: float,
    user_lon: float,
    skip: int = 0,
    limit: int = 10,
    hearted_only: bool = False,
    user: User = Depends(current_active_user),
    db: AsyncSession = Depends(get_async_session),
    restaurant_service: RestaurantPostServiceProtocol=Depends(get_restaurant_post_service),
):
    return await restaurant_service.list(
        db=db,
        user_id=user.id,
        skip=skip,
        limit=limit,
        user_lat=user_lat,
        user_lon=user_lon,
        hearted_only=hearted_only
    )

@router.post("/update")
async def update_restaurant(
    request: RestaurantPostUpdate,
    restaurant_service: RestaurantPostService = Depends(get_restaurant_post_service),
    db: AsyncSession = Depends(get_async_session),
    user: User = Depends(current_active_user),
):
    request.editor_id = user.id
    return await restaurant_service.update(db, obj_in=request)

@router.get("/{post_id}/versions", response_model=List[RestaurantPostVersionBase])
async def get_post_versions(
    post_id: int,
    skip: int = 0,
    limit: int = 10,
    user: User = Depends(current_active_user),  # 계정 인증용
    db: AsyncSession = Depends(get_async_session),
    version_crud: RestaurantPostVersionCRUD = Depends(get_restaurant_post_version_crud),
):
    return await version_crud.get_versions_by_post_id(db, post_id, skip, limit)

@router.post("/rollback")
async def rollback_restaurant(
    version_id: int,
    user: User = Depends(current_active_user), # 계정 인증용
    db: AsyncSession = Depends(get_async_session),
    restaurant_service: RestaurantPostService = Depends(
            get_restaurant_post_service),
):
    return await restaurant_service.rollback(db=db, version_id=version_id)

@router.post("/image/{post_id}/create", response_model=Optional[RestaurantPostImageBase])
async def create_restaurant_post_image(
    post_id: int,
    image: UploadFile = File(...),
    db: AsyncSession = Depends(get_async_session),
    user: User = Depends(current_active_user),
    restaurant_post_image_service: RestaurantPostImageServiceProtocol =\
         Depends(get_restaurant_post_image_service)
):
    return await restaurant_post_image_service.create(
        db=db,
        post_id=post_id,
        image=image,
        editor_id=user.id,
    )

@router.get("/image/{post_id}/list")
async def get_restaurant_post_image_list(
    post_id: int,
    skip: int = 0,
    limit: int = 10,
    user: User = Depends(current_active_user),
    db: AsyncSession = Depends(get_async_session),
    restaurant_post_image_crud: RestaurantPostImageCRUDProtocol =\
        Depends(get_restaurant_post_image_crud)
):
    return await restaurant_post_image_crud.list_by_restaurant_id(
        db=db,
        skip=skip,
        limit=limit,
        restaurant_id=post_id,
    )

@router.get("/image/{post_id}/versions", response_model=List[RestaurantPostImageSetVersionBase])
async def get_restaurant_post_image_versions(
    post_id: int,
    skip: int = 0,
    limit: int = 10,
    user: User = Depends(current_active_user),
    db: AsyncSession = Depends(get_async_session),
    image_set_version_crud = Depends(get_restaurant_post_image_set_version_crud)
):
    return await image_set_version_crud.get_versions_by_post_id(
        db=db,
        post_id=post_id,
        skip=skip,
        limit=limit
    )

@router.delete("/image/{image_id}/delete")
async def delete_restaurant_post_image(
    image_id: int,
    db: AsyncSession = Depends(get_async_session),
    user: User = Depends(current_active_user),
    restaurant_post_image_service: RestaurantPostImageServiceProtocol = Depends(
        get_restaurant_post_image_service
    )
):
    await restaurant_post_image_service.delete(
        db, image_id=image_id, user_id=user.id
    )

@router.post("/image/{version_id}/rollback")
async def rollback_restaurant_post_image(
    version_id: int,
    db: AsyncSession = Depends(get_async_session),
    user: User = Depends(current_active_user),
    restaurant_post_image_service: RestaurantPostImageServiceProtocol =\
         Depends(get_restaurant_post_image_service)
):
    await restaurant_post_image_service.rollback(
        db=db,
        version_id=version_id,
        editor_id=user.id,
    )