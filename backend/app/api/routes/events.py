import asyncio
import json
import logging

from aioredis.exceptions import ConnectionError as ServerConnectionError
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


async def ws_send(websocket: WebSocket, queue_key: str,
                  disconnect_event: asyncio.Event):
    pool = await get_redis()
    last_event_id = websocket.query_params.get('last_event_id', '$')

    try:
        while pool and not disconnect_event.is_set():
            try:
                events = await pool.xread(streams={queue_key: last_event_id},
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
                    WebSocketDisconnect, ServerConnectionError):
                disconnect_event.set()

            except Exception as e:
                logger.error(f"send 예상치 못한 오류 발생: {e}")
                disconnect_event.set()
    finally:
        logger.error(f"redis 연결이 종료되었습니다.")
        disconnect_event.set()
        await redis_client.close_connection()


async def ws_receive(websocket: WebSocket, disconnect_event: asyncio.Event):
    while not disconnect_event.is_set():
        try:
            await websocket.receive_text()
        except (ConnectionClosedError, ConnectionClosedOK, WebSocketDisconnect):
            logger.info("클라이언트 연결이 종료되었습니다.")
            disconnect_event.set()
            await redis_client.close_connection()
        except Exception as e:
            logger.error(f"receive 예상치 못한 오류 발생: {e}")
            disconnect_event.set()
            await redis_client.close_connection()


@router.websocket("/connect")
async def connect_event(
        websocket: WebSocket,
        db: AsyncSession = Depends(get_async_session),
        user_crud: UserCRUDProtocol = Depends(get_user_crud),
        websocket_authenticator: WebSocketAuthenticator = Depends(
            get_socket_authenticator)
):
    user = await websocket_authenticator.authenticate(websocket)
    await websocket_manager.connect(websocket)

    # 사용자 상태를 '온라인'으로 업데이트
    update_data = UserUpdate(id=user.id, is_online=True)
    await user_crud.update(db, user_in=update_data)

    # disconnect_event 생성
    disconnect_event = asyncio.Event()

    try:
        # WebSocket 연결 설정
        queue_key = f"queue:{user.id}"
        await asyncio.gather(
            ws_receive(websocket, disconnect_event),
            ws_send(websocket, queue_key, disconnect_event)
        )
    finally:
        # WebSocket 연결이 종료되면 사용자 상태를 '오프라인'으로 업데이트
        update_data = UserUpdate(id=user.id, is_online=False)
        await user_crud.update(db, user_in=update_data)
        logger.info(f"사용자 {user.id}의 상태를 오프라인으로 업데이트했습니다.")
        websocket_manager.disconnect(websocket)
