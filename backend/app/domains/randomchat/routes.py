from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_async_session
from app.core.security import current_active_user
from app.domains.randomchat.schemas import QueueStatus
from app.domains.randomchat.service import RandomChatService, get_random_chat_service
from app.models import User

def prevent_queue_cache(response: Response):
    response.headers["Cache-Control"] = "no-store"


router = APIRouter(
    dependencies=[Depends(prevent_queue_cache)],
    responses={
        401: {"description": "Active verified authentication required"},
        403: {"description": "Account is no longer eligible to join"},
        503: {"description": "Storage unavailable; reconcile status before retrying"},
    },
)


async def queue_action(
    service: RandomChatService, action: Literal["join", "leave", "status"],
    db: AsyncSession, user_id: int,
) -> QueueStatus:
    try:
        return await getattr(service, action)(db, user_id)
    except PermissionError as exc:
        raise HTTPException(
            status_code=403, detail="참가 가능한 계정이 아닙니다.",
            headers={"Cache-Control": "no-store"},
        ) from exc
    except SQLAlchemyError as exc:
        raise HTTPException(
            status_code=503,
            detail={
                "code": "random_chat_unavailable",
                "message": "매칭 상태를 확인하지 못했습니다. 잠시 후 다시 확인해주세요.",
            },
            headers={"Cache-Control": "no-store"},
        ) from exc


@router.post("/match/queue/join", response_model=QueueStatus)
async def match_queue_join(
    user: User = Depends(current_active_user),
    db: AsyncSession = Depends(get_async_session),
    service: RandomChatService = Depends(get_random_chat_service),
) -> QueueStatus:
    return await queue_action(service, "join", db, user.id)


@router.get("/match/queue", response_model=QueueStatus)
async def match_queue_status(
    user: User = Depends(current_active_user),
    db: AsyncSession = Depends(get_async_session),
    service: RandomChatService = Depends(get_random_chat_service),
) -> QueueStatus:
    return await queue_action(service, "status", db, user.id)


@router.post("/match/queue/leave", response_model=QueueStatus)
async def match_queue_leave(
    user: User = Depends(current_active_user),
    db: AsyncSession = Depends(get_async_session),
    service: RandomChatService = Depends(get_random_chat_service),
) -> QueueStatus:
    return await queue_action(service, "leave", db, user.id)
