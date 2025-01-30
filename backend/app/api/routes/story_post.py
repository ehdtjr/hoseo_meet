from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from starlette import status

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


@router.post("/subscribe/{story_post_id}")
async def subscribe_to_story_post(
    story_post_id: int,
    db: AsyncSession = Depends(get_async_session),
    user: User = Depends(current_active_user),
    story_post_service: StoryPostService = Depends(get_story_post_service),
):
    """
    특정 story_post에 대해 사용자를 구독시키는 엔드포인트입니다.
    - 존재하지 않는 스토리인 경우 HTTP 400 예외를 발생시킵니다.
    - 이미 구독된 경우 HTTP 400 예외를 발생시킵니다.
    """
    try:
        # 구독 처리
        result = await story_post_service.subscribe_to_story_post(
            db, user.id, story_post_id
        )
        return {"success": result}

    except ValueError as e:
        # 적절한 예외 메시지와 함께 400 에러 반환
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
