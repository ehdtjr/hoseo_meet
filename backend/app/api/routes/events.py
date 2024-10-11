import json
import logging

from aioredis import Redis
from fastapi import APIRouter, Depends
from sqlmodel.ext.asyncio.session import AsyncSession
from starlette.websockets import WebSocket, WebSocketDisconnect
from websockets import ConnectionClosedError, ConnectionClosedOK

from app.api.deps import get_redis
from app.core.db import get_async_session
from app.core.redis import redis_client
from app.crud.user_crud import UserCRUDProtocol, get_user_crud
from app.schemas.user import UserUpdate
from app.service.websocket_connection import WebSocketAuthenticator, \
    WebSocketConnection, get_socket_authenticator

router = APIRouter()

# WebSocket 연결 관리 인스턴스 생성
websocket_manager = WebSocketConnection()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@router.websocket("/connect")
async def connect_event(
        websocket: WebSocket,
        redis: Redis = Depends(get_redis),
        db: AsyncSession = Depends(get_async_session),
        user_crud: UserCRUDProtocol = Depends(get_user_crud),
        websocket_authenticator: WebSocketAuthenticator = Depends(
            get_socket_authenticator)
):
    ws_connected = True
    user = await websocket_authenticator.authenticate(websocket)

    # 사용자 상태를 '온라인'으로 업데이트
    update_data = UserUpdate(id=user.id, is_online=True)
    await user_crud.update(db, user_in=update_data)

    # WebSocket 연결 설정
    await websocket_manager.connect(websocket)
    queue_key = f"queue:{user.id}"
    last_event_id = websocket.query_params.get('last_event_id', '$')

    try:
        while ws_connected and redis:
            try:
                # WebSocket 상태 로깅
                logger.info(f"WebSocket 상태: {websocket.client_state}")
                logger.info(f"WebSocket 연결 중: {ws_connected}")

                # 클라이언트로부터 메시지를 수신하여 연결 상태를 확인
                try:
                    await websocket.receive_text()
                except WebSocketDisconnect:
                    logger.info("WebSocket 연결이 끊어졌습니다.")
                    break

                events = await redis.xread(streams={queue_key: last_event_id},
                                           block=0, count=100)
                if events:
                    for stream_name, event_list in events:
                        for event_id, event_data in event_list:
                            # 이벤트 데이터 파싱
                            if "data" in event_data and isinstance(
                                    event_data["data"], str):
                                try:
                                    event_data["data"] = json.loads(
                                        event_data["data"])
                                except json.JSONDecodeError:
                                    logger.warning(f"JSON 파싱 실패: {event_data}")
                                    continue

                            # 이벤트를 WebSocket 클라이언트로 전송
                            event_data["last_event_id"] = event_id
                            event_data_json = json.dumps(event_data,
                                                         ensure_ascii=False)
                            await websocket_manager.send_message(
                                event_data_json, websocket)
                            last_event_id = event_id

            except (
                    ConnectionClosedError, ConnectionClosedOK,
                    WebSocketDisconnect):
                logger.info("WebSocket 연결이 종료되었습니다.")
                ws_connected = False

            except Exception as e:
                logger.error(f"예상치 못한 오류 발생: {e}")
                ws_connected = False

    finally:
        # 종료 시 리소스 정리
        logger.info("WebSocket 연결 종료 및 정리 중.")
        websocket_manager.disconnect(websocket)
        await redis_client.close_connection()
        if user:
            update_data = UserUpdate(id=user.id, is_online=False)
            await user_crud.update(db, user_in=update_data)
