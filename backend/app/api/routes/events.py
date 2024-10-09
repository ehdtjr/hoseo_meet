import json
import logging

from aioredis import Redis
from fastapi import APIRouter, Depends
from sqlmodel.ext.asyncio.session import AsyncSession
from starlette.websockets import WebSocket, WebSocketDisconnect, WebSocketState

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


# WebSocket 라우터 정의
@router.websocket("/connect")
async def connect_event(
        websocket: WebSocket,
        redis: Redis = Depends(get_redis),
        db: AsyncSession = Depends(get_async_session),
        user_crud: UserCRUDProtocol = Depends(get_user_crud),
        websocket_authenticator: WebSocketAuthenticator = Depends(
            get_socket_authenticator)
):
    user = None
    try:
        user = await websocket_authenticator.authenticate(websocket)
        # user online으로 전환
        update_data = UserUpdate(id=user.id, is_online=True)
        await user_crud.update(db, user_in=update_data)

        await websocket_manager.connect(websocket)
        queue_key = f"queue:{user.id}"
        last_event_id = websocket.query_params.get('last_event_id', '$')

        # 초기 count 값 설정
        min_count = 10
        max_count = 1000
        current_count = min_count

        while websocket.client_state == WebSocketState.CONNECTED:
            # Redis에서 대기, 이벤트 가져오기
            events = await redis.xread({queue_key: last_event_id}, block=5000,
                                       count=current_count)

            if events:
                # 가져온 이벤트 처리
                for stream_name, event_list in events:
                    for event_id, event_data in event_list:
                        if "data" in event_data and isinstance(
                                event_data["data"], str):
                            try:
                                event_data["data"] = json.loads(
                                    event_data["data"])
                            except json.JSONDecodeError:
                                logger.warning(
                                    f"JSON parsing failed for event: "
                                    f"{event_data}")
                                continue  # 파싱 실패 시 해당 이벤트는 건너뜀

                        event_data["last_event_id"] = event_id
                        event_data_json = json.dumps(event_data,
                                                     ensure_ascii=False)
                        await websocket_manager.send_message(event_data_json,
                                                             websocket)
                        last_event_id = event_id

                # 이벤트가 많다면 current_count 값을 증가시켜 더 많은 이벤트를 가져옴
                current_count = min(current_count * 2, max_count)
            else:
                # 이벤트가 없거나 적다면 current_count 값을 줄임
                current_count = max(current_count // 2, min_count)


    except WebSocketDisconnect:
        logger.info("WebSocket disconnected.")

    except Exception as e:
        logger.error(f"Exception in WebSocket connection: {e}")

    finally:
        if user:
            websocket_manager.disconnect(websocket)
            update_data = UserUpdate(id=user.id, is_online=False)
            await user_crud.update(db, user_in=update_data)
        websocket_manager.disconnect(websocket)
        await redis_client.close_connection()
