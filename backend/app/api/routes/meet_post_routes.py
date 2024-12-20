from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from typing_extensions import Optional

from app.core.db import get_async_session
from app.core.security import current_active_user
from app.models import User
from app.schemas.meet_post import MeetPostBase, MeetPostRequest, \
    MeetPostResponse
from app.service.meet_post import MeetPostServiceProtocol, \
    get_meet_post_service

router = APIRouter()


@router.post("/create", response_model=MeetPostBase)
async def create_meet_post(
    meet_post: MeetPostRequest,
    db: AsyncSession = Depends(get_async_session),
    user: User = Depends(current_active_user),
    meet_post_service: MeetPostServiceProtocol = Depends(get_meet_post_service),
):
    """
    meet_post를 등록하는 엔드포인트입니다.
    - 사용자가 등록한 meet_post는 자동으로 채팅방이 생성됩니다.
    - 사용자가 등록한 meet_post는 해당 채팅방에 자동으로 참여합니다.
    - 사용 가능한 type은 "meet", "delivery", "taxi", "carpool" 입니다.
    """
    result: MeetPostBase = await meet_post_service.create_meet_post(
        db, meet_post=meet_post, user_id=user.id)
    return result


@router.get("/search", response_model=Optional[list[MeetPostResponse]])
async def get_filtered_meet_posts(
    title: Optional[str] = None,
    type: Optional[str] = None,
    content: Optional[str] = None,
    skip: int = 0,
    limit: int = 10,
    db: AsyncSession = Depends(get_async_session),
    meet_post_service: MeetPostServiceProtocol = Depends(get_meet_post_service),
):
    result = await meet_post_service.get_filtered_meet_posts(
        db, title, type, content, skip, limit)
    return result

@router.post("/subscribe/{meet_post_id}")
async def subscribe_to_meet_post(
        meet_post_id: int,
        db: AsyncSession = Depends(get_async_session),
        user: User = Depends(current_active_user),
        meet_post_service: MeetPostServiceProtocol = Depends(get_meet_post_service),
):
    """
    특정 meet_post에 대해 사용자를 구독시키는 엔드포인트입니다.
    - 최대 인원을 초과하는 경우 HTTP 400 예외를 발생시킵니다.
    - 이미 구독된 경우에도 HTTP 400 예외를 발생시킵니다.
    """
    try:
        # 구독 처리
        result = await meet_post_service.subscribe_to_meet_post(
            db, user.id, meet_post_id
        )
        return {"success": result}

    except ValueError as e:
        # 적절한 예외 메시지와 함께 400 에러 반환
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))