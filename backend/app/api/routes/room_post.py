# file: app/api/endpoints/room_post.py
from typing import Optional, List
from fastapi import APIRouter, Depends, Form, File, UploadFile, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_async_session
from app.core.security import current_active_user
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
    RoomReviewResponse,
)

router = APIRouter()


# 자취방 목록 조회
@router.get("/rooms", response_model=List[RoomPostListResponse])
async def get_room_posts(
    place: Optional[str] = None,
    sort_by: Optional[str] = None,  # "distance", "reviews", "rating"
    user_lat: Optional[float] = None,
    user_lon: Optional[float] = None,
    skip: int = 0,
    limit: int = 10,
    db: AsyncSession = Depends(get_async_session),
    service: RoomPostServiceProtocol = Depends(get_room_post_service),
):
    return await service.get_room_posts(
        db,
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

    detail = await service.get_room_post_detail(db, room_id, user_lat, user_lon)
    if not detail:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Room post not found"
        )
    return detail


# 리뷰 작성
@router.post("/create_review", response_model=RoomReviewResponse)
async def create_review(
    room_id: int = Form(...),
    content: str = Form(...),
    rating: float = Form(...),
    images: Optional[List[UploadFile]] = File(None),
    db: AsyncSession = Depends(get_async_session),
    user: User = Depends(current_active_user),
    review_service: RoomReviewService = Depends(get_room_review_service),
):

    images = images or []

    review = await review_service.create_room_review(
        db=db,
        user_id=user.id,
        room_id=room_id,
        content=content,
        rating=rating,
        images=images,
    )
    return review


# 리뷰 조회
@router.get("/get_reviews", response_model=List[RoomReviewResponse])
async def get_reviews(
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
