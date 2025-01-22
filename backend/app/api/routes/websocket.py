import asyncio
import logging

from fastapi import APIRouter, Depends
from starlette.websockets import WebSocket

from app.core.db import get_async_session_context
from app.crud.user import UserCRUDProtocol, get_user_crud
from app.models import User
from app.schemas.user import UserUpdate
from app.service.websocket.websocket_handler import WebSocketEventHandler
from app.service.websocket.websocket_manager import (WebSocketManager,
get_authenticated_user)

router = APIRouter()

logger = logging.getLogger(__name__)

websocket_manager = WebSocketManager()
event_handler = WebSocketEventHandler(websocket_manager)


@router.websocket("/connect")
async def connect_event(
        websocket: WebSocket,
        user: User = Depends(get_authenticated_user),
):
    # 인증을 통해 사용자 정보 확인
    disconnect_event = asyncio.Event()

    try:
        # WebSocket 이벤트 핸들러 시작
        await event_handler.handle_connection(websocket,
             user_id=user.id, disconnect_event=disconnect_event)
    finally:
        logger.info(f"사용자 {user.id}의 상태를 오프라인으로 업데이트했습니다.")