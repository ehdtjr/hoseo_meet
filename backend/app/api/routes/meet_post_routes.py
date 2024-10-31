from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from typing_extensions import Optional

from app.core.db import get_async_session
from app.core.security import current_active_user
from app.models import User
from app.schemas.meet_post_schemas import MeetPostBase, MeetPostCreate, \
    MeetPostRequest
from app.service.meet_post_service import MeetPostService, \
    MeetPostServiceProtocol, get_meet_post_service

router = APIRouter()


@router.post("/create", response_model=MeetPostBase)
async def create_meet_post(
    meet_post: MeetPostRequest,
    db: AsyncSession = Depends(get_async_session),
    user: User = Depends(current_active_user),
    meet_post_service: MeetPostServiceProtocol = Depends(get_meet_post_service),
):
    result: MeetPostBase = await meet_post_service.create_meet_post(
        db, meet_post=meet_post, user_id=user.id)
    return result


@router.get("/search", response_model=Optional[list[MeetPostBase]])
async def get_filtered_meet_posts(
    title: Optional[str] = None,
    post_type: Optional[str] = None,
    content: Optional[str] = None,
    skip: int = 0,
    limit: int = 10,
    db: AsyncSession = Depends(get_async_session),
    meet_post_service: MeetPostServiceProtocol = Depends(get_meet_post_service),
):
    result = await meet_post_service.get_filtered_meet_posts(
        db, title, post_type, content, skip, limit)
    return result
