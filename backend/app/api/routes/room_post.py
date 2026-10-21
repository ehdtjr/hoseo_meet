from typing import Optional, List
from fastapi import APIRouter, Depends, Form, File, UploadFile, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.responses import JSONResponse

from app.core.db import get_async_session
from app.core.exceptions import ConflictException, NotFoundException
from app.core.security import current_active_user
from app.crud.room_post import get_room_post_heart, RoomPostHeartCRUDProtocol
from app.models.user import User
from app.service.room_post import (
    get_room_review_service,
    RoomReviewService,
    RoomPostServiceProtocol,
    get_room_post_service,
)
from app.schemas.room_post import (
    RoomPostListResponse,
    RoomPostDetailResponse,
    RoomReviewResponse, RoomReviewImageBase, RoomPostHeartBase,
)

router = APIRouter()


# 자취방 목록 조회
@router.get("/rooms", response_model=List[RoomPostListResponse])
async def get_room_posts(
    place: Optional[str] = None,
    name:Optional[str] = None,
    sort_by: Optional[str] = "rating",
    user_lat: Optional[float] = None,
    user_lon: Optional[float] = None,
    skip: int = 0,
    limit: int = 10,
    user: User = Depends(current_active_user),
    db: AsyncSession = Depends(get_async_session),
    service: RoomPostServiceProtocol = Depends(get_room_post_service),
):
    return await service.get_room_posts(
        db,
        user_id = user.id,
        name=name,
        place=place,
        sort_by=sort_by,
        user_lat=user_lat,
        user_lon=user_lon,
        skip=skip,
        limit=limit,
    )

# 자취방 상세 조회
@router.get("/rooms/{room_id}", response_model=RoomPostDetailResponse)
async def get_room_post_detail(
    room_id: int,
    user_lat: Optional[float] = None,
    user_lon: Optional[float] = None,
    db: AsyncSession = Depends(get_async_session),
    service: RoomPostServiceProtocol = Depends(get_room_post_service),
):

    detail = await service.get_room_post_detail(
        db, room_id, user_lat, user_lon)
    if not detail:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Room post not found"
        )
    return detail

@router.post("/rooms/heart/{room_id}", tags=["RoomHeart"])
async def create_heart_room(
    room_id: int,
    user: User = Depends(current_active_user),
    db: AsyncSession = Depends(get_async_session),
    crud: RoomPostHeartCRUDProtocol = Depends(get_room_post_heart),
):
    room_post_heart = RoomPostHeartBase(
        user_id=user.id,
        room_id=room_id
    )

    try:
        await crud.create(db, room_post_heart)

    except IntegrityError as e:
        if "uq_user_room_heart" in str(e.orig):
            raise ConflictException("이미 하트를 누르셨습니다 ")
    except HTTPException:
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={"detail": "알 수 없는 오류가 발생했습니다."}
        )

    return JSONResponse(
        status_code=status.HTTP_201_CREATED,
        content={"message": "하트 등록 완료"}
    )

@router.delete("/rooms/heart/{room_id}", tags=["RoomHeart"])
async def delete_heart_room(
    room_id: int,
    user: User = Depends(current_active_user),
    db: AsyncSession = Depends(get_async_session),
    crud: RoomPostHeartCRUDProtocol = Depends(get_room_post_heart),
):
    room_post_heart: RoomPostHeartBase = await crud.get_by_user_and_room(db, user_id=user.id, room_id=room_id)
    if not room_post_heart:
        raise NotFoundException("하트가 없습니다")
    try:
        await crud.delete(db,room_post_heart.id)
        return JSONResponse(
            status_code=status.HTTP_204_NO_CONTENT,
            content={"detail": "하트 삭제 완료"}
        )
    except HTTPException:
        return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "알 수 없는 오류가 발생했습니다"}
    )

# 리뷰 작성
@router.post("/review/{room_id}/create", response_model=RoomReviewResponse)
async def create_review(
    room_id: int,
    content: str = Form(...),
    rating: float = Form(..., ge=0.0, le=5.0),
    images: Optional[List[UploadFile]] = File(None),
    db: AsyncSession = Depends(get_async_session),
    user: User = Depends(current_active_user),
    review_service: RoomReviewService = Depends(get_room_review_service),
):
    try:
        if not images:
            images = []

        review = await review_service.create_room_review(
            db=db,
            user_id=user.id,
            room_id=room_id,
            content=content,
            rating=rating,
            images=images,
        )
        return review

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"{str(e)}")


# 리뷰 리스트 조회
@router.get("/review/{room_id}/list", response_model=List[RoomReviewResponse])
async def reviews(
    room_id: int,
    page: int = 1,
    page_size: int = 5,
    sort_by: str = "latest",
    db: AsyncSession = Depends(get_async_session),
    review_service: RoomReviewService = Depends(get_room_review_service),
):
    return await review_service.get_room_reviews(
        db=db, room_id=room_id, page=page, page_size=page_size, sort_by=sort_by
    )


# 리뷰 삭제
@router.delete("/review/{review_id}/delete", response_model=RoomReviewResponse)
async def delete_review(
    review_id: int,
    db: AsyncSession = Depends(get_async_session),
    user: User = Depends(current_active_user),
    review_service: RoomReviewService = Depends(get_room_review_service),
):
    deleted_review = await review_service.delete_review_by_id(
        db=db, review_id=review_id, user_id=user.id
    )
    if not deleted_review:
        # None이 반환되었다면 "리뷰가 없거나 권한이 없음"
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Review not found or no permission",
        )

    return deleted_review


# 리뷰 이미지 목록 조회
@router.get(
"/review/{room_id}/image_list",
    response_model=Optional[List[RoomReviewImageBase]]
)
async def get_room_review_images(
    room_id: int,
    skip: int = 0,
    limit: int = 10,
    db: AsyncSession = Depends(get_async_session),
    review_service=Depends(
        get_room_review_service
    )
):
    try:
        response = await review_service.get_room_images_by_room(
            db=db, room_id=room_id, skip=skip, limit=limit
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get room images: {e}")
    return response
