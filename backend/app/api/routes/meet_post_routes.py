from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

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
    meet_post_data: MeetPostRequest,db: AsyncSession = Depends(get_async_session),
    user: User = Depends(current_active_user),
    meet_post_service: MeetPostServiceProtocol = Depends(get_meet_post_service),
):
    meet_post = MeetPostCreate(
        title=meet_post_data.title,
        author_id=user.id,
        type=meet_post_data.type,
        content=meet_post_data.content,
        max_people=meet_post_data.max_people,
    )
    result: MeetPostBase = await meet_post_service.create_meet_post(db,
    meet_post)
    return result