from fastapi import WebSocket
from fastapi.params import Depends
from fastapi_users import BaseUserManager, models
from fastapi_users.authentication import JWTStrategy
from websockets import ConnectionClosedError, ConnectionClosedOK

from app.core.security import get_jwt_strategy
from app.service.user import get_user_manager


class WebSocketAuthenticator:
    def __init__(self, jwt_strategy: JWTStrategy,
                 user_manager: BaseUserManager[models.UP, models.ID]):
        self.jwt_strategy = jwt_strategy
        self.user_manager = user_manager

    async def authenticate(self, websocket: WebSocket):
        token = websocket.headers.get("sec-websocket-protocol")

        if not token:
            await websocket.close(code=1008, reason="Missing protocol header")
            return

        user = await self.jwt_strategy.read_token(token,
                                                  user_manager=self.user_manager)
        if not user.is_verified or not user.is_active:
            await websocket.close(code=1008)
        return user


def get_socket_authenticator(
        jwt_strategy: JWTStrategy = Depends(get_jwt_strategy),
        user_manager: BaseUserManager[models.UP,
        models.ID] = Depends(get_user_manager)):
    return WebSocketAuthenticator(jwt_strategy, user_manager)


class WebSocketConnection:
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

    async def broadcast(self, message: str):
        to_remove = []
        for connection in self.active_connection:
            try:
                await connection.send_text(message)
            except (ConnectionClosedOK, ConnectionClosedError):
                to_remove.append(connection)

        # 닫힌 연결을 목록에서 제거
        for connection in to_remove:
            self.disconnect(connection)
