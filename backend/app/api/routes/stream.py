from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_async_session
from app.core.security import current_active_user
from app.models import User
from app.schemas.stream import StreamCreate, StreamRead, StreamRequest
from app.service.stream import StreamServiceProtocol, get_stream_service

router = APIRouter()


@router.post("/create", response_model=StreamRead)
async def create_stream(
        stream_request: StreamRequest,
        db: AsyncSession = Depends(get_async_session),
        stream_service: StreamServiceProtocol = Depends(get_stream_service),
        user: User = Depends(current_active_user)
):
    merge_create = StreamCreate(**stream_request.model_dump(),
                                creator_id=user.id)
    new_stream = await stream_service.create_stream(db, merge_create)
    return new_stream
