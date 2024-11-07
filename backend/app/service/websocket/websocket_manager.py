from typing import Protocol

from fastapi import WebSocket
from fastapi.params import Depends
from fastapi_users import BaseUserManager
from fastapi_users_db_sqlalchemy import SQLAlchemyUserDatabase
from sqlalchemy.ext.asyncio import AsyncSession
from websocket import WebSocketException
from websockets import ConnectionClosedError, ConnectionClosedOK

from app.core.db import get_async_session, get_async_session_context
from app.core.security import auth_backend
from app.models import User
from app.service.email import get_email_service
from app.service.user import get_user_manager, UserManager

import logging

logger = logging.getLogger(__name__)


class WebSocketAuthenticator:
    def __init__(self, user_manager: BaseUserManager[User, int]):
        self.user_manager = user_manager

    async def authenticate(self, websocket: WebSocket):
        token = websocket.headers.get("sec-websocket-protocol")

        if not token:
            await websocket.close(code=1008, reason="Missing protocol header")
            return

        user = await auth_backend.get_strategy().read_token(
            token, user_manager=self.user_manager)

        if not user:
            await websocket.close(code=1008, reason="유저가 존재하지 않습니다")
        if not user.is_active:
            await websocket.close(code=1008, reason="사용이 정지된 유저 입니다")
        if not user.is_verified:
            await websocket.close(code=1008, reason="이메일 인증을 완료해주세요")
        return user



async def get_authenticated_user(
    websocket: WebSocket
):
    async with get_async_session_context() as session:
        user_db = SQLAlchemyUserDatabase(session, User)
        user_manager = UserManager(user_db, get_email_service())
        authenticator = WebSocketAuthenticator(user_manager)
        user = await authenticator.authenticate(websocket)
    return user



class WebSocketManagerProtocol(Protocol):
    async def connect(self, websocket: WebSocket):
        pass

    def disconnect(self, websocket: WebSocket):
        pass

    async def send_message(self, message: str, websocket: WebSocket):
        pass

class WebSocketManager(WebSocketManagerProtocol):
    def __init__(self):
        self.active_connection: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        protocol_header = websocket.headers.get("sec-websocket-protocol")

        if protocol_header:
            await websocket.accept(subprotocol=protocol_header)
        else:
            await websocket.accept()
        self.active_connection.append(websocket)

    def disconnect(self, websocket: WebSocket):
        try:
            self.active_connection.remove(websocket)
        except ValueError:
            print("연결 해제 중 연결을 찾지 못했습니다.")

    async def send_message(self, message: str, websocket: WebSocket):
        try:
            await websocket.send_text(message)
        except (ConnectionClosedOK, ConnectionClosedError):
            self.disconnect(websocket)
            print("웹소켓 연결이 닫혀 메시지를 전송할 수 없습니다.")