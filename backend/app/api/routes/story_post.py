from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_async_session
from app.core.security import current_active_user
from app.models import User
from app.schemas.story_post import StoryPostResponse, \
    StoryPostRequest
from app.service.story_post import StoryPostService, get_story_post_service

router = APIRouter()

@router.post("/upload_image", response_model=dict)
async def upload_story_image(
    file: UploadFile = File(...),
    user: User = Depends(current_active_user),
    story_post_service: StoryPostService = Depends(get_story_post_service),
) -> dict[str, str]:
    if file.content_type not in ["image/jpeg", "image/png", "image/webp"]:
        raise HTTPException(status_code=400, detail="File type not supported")
    image_url = await story_post_service.upload_image(user.id, file)

    return {"url": image_url}

@router.post("/create", response_model=StoryPostResponse)
async def create_story_post(
    story_request: StoryPostRequest,
    db: AsyncSession = Depends(get_async_session),
    user: User = Depends(current_active_user),
    story_post_service: StoryPostService = Depends(get_story_post_service),
) -> StoryPostResponse:

    return await story_post_service.create_story_post(
        db=db,
        user_id=user.id,
        story_request=story_request,
    )

@router.get("/list", response_model=list[StoryPostResponse])
async def list_story_posts(
    db: AsyncSession = Depends(get_async_session),
    user: User = Depends(current_active_user),
    story_post_service: StoryPostService = Depends(get_story_post_service),
) -> list[StoryPostResponse]:
    return await story_post_service.list_story_post(db=db, user_id=user.id)

@router.get("/{story_post_id}", response_model=StoryPostResponse)
async def get_story_post(
    story_post_id: int,
    user: User = Depends(current_active_user),
    db: AsyncSession = Depends(get_async_session),
    story_post_service: StoryPostService = Depends(get_story_post_service),
) -> StoryPostResponse:
    return await story_post_service.get_detail_story_post(
        db=db,
        user_id=user.id,
        story_post_id=story_post_id,
    )
