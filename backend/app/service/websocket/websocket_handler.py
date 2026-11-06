import asyncio
import json
import logging
from starlette.websockets import WebSocket, WebSocketDisconnect
from aioredis.exceptions import ConnectionError as ServerConnectionError
from websockets.exceptions import ConnectionClosedError, ConnectionClosedOK

from app.core.metrics import connected_websockets
from app.core.redis import redis_client
from app.service.websocket.websocket_manager import WebSocketManagerProtocol

logger = logging.getLogger(__name__)


# Log protocol constants only. Never stringify payloads, exception messages,
# close reasons, headers, cursor values or unknown event types.
def _safe_event_type(event_data: dict) -> str:
    event_type = event_data.get("type")
    if isinstance(event_type, str) and event_type in ("stream", "user", "location", "read"):
        return event_type
    return "unknown"


class WebSocketEventHandler:
    def __init__(self, websocket_manager: WebSocketManagerProtocol):
        self.websocket_manager = websocket_manager

    async def handle_connection(self, websocket: WebSocket, user_id: int,
                                disconnect_event: asyncio.Event):
        """
        WebSocket 연결을 관리하고, Redis 이벤트를 수신하여 WebSocket 클라이언트로 전송합니다.
        """
        await self.websocket_manager.connect(websocket)
        connected_websockets.inc()  # 웹소켓 연결자 수 파악을 위한 프로메테우스

        queue_key = f"queue:{user_id}"

        # 코루틴들을 태스크로 변환하여 실행
        tasks = [
            asyncio.create_task(self._receive_from_redis(websocket, queue_key,
                                                         disconnect_event)),
            asyncio.create_task(
                self._receive_ws_messages(websocket, disconnect_event))
        ]

        try:
            await asyncio.gather(*tasks)  # 예외 발생 시 모든 작업 취소
        except Exception:
            logger.error("websocket connection_failed")
        finally:
            # 모든 태스크 취소
            for task in tasks:
                task.cancel()
            # 연결 종료 및 상태 감소
            logger.info("websocket disconnected")
            connected_websockets.dec()
            self.websocket_manager.disconnect(websocket)

    async def _receive_from_redis(self, websocket: WebSocket, queue_key: str,
                                  disconnect_event: asyncio.Event):
        """
        Redis로부터 이벤트를 수신하고 WebSocket으로 전송합니다.
        """
        last_event_id = websocket.query_params.get('last_event_id', '$')
        pool = redis_client.redis
        while not disconnect_event.is_set():
            try:
                events = await pool.xread(
                    streams={queue_key: last_event_id}, block=0, count=100)
                if events:
                    await self._process_and_send_events(events, websocket)
                    last_event_id = events[-1][1][-1][0]
            except (ConnectionClosedError, ConnectionClosedOK,
                    WebSocketDisconnect) as e:
                logger.info("websocket redis_forwarding_disconnected")
                disconnect_event.set()
                raise e
            except ServerConnectionError as e:
                logger.error("websocket redis_connection_failed")
                disconnect_event.set()
                raise e
            except Exception as e:
                logger.error("websocket redis_forwarding_failed")
                disconnect_event.set()
                raise e


    async def _receive_ws_messages(self, websocket: WebSocket,
                                   disconnect_event: asyncio.Event):
        """
        WebSocket 클라이언트로부터 수신을 처리하고, 종료 시 이벤트를 설정합니다.
        """
        while not disconnect_event.is_set():
            try:
                await websocket.receive_text()
                logger.debug("websocket client_frame_received")
            except (ConnectionClosedError, ConnectionClosedOK,
                    WebSocketDisconnect) as e:
                logger.info("websocket client_disconnected")
                disconnect_event.set()
                raise e
            except Exception as e:
                logger.error("websocket receive_failed")
                disconnect_event.set()
                raise e

    async def _process_and_send_events(self, events, websocket: WebSocket):
        """
        수신된 Redis 이벤트를 WebSocket 클라이언트로 전송 가능한 형식으로 처리하여 전송합니다.
        """
        for stream_name, event_list in events:
            for event_id, event_data in event_list:
                await self._send_event(websocket, event_id, event_data)

    async def _send_event(self, websocket: WebSocket, event_id: str, event_data: dict):
        """
        WebSocket 클라이언트에 이벤트 데이터를 전송합니다.
        """
        if "data" in event_data and isinstance(event_data["data"], str):
            event_data = self._parse_event_data(event_data)

        event_data["last_event_id"] = event_id
        event_data_json = json.dumps(event_data, ensure_ascii=False)
        try:
            await self.websocket_manager.send_message(event_data_json, websocket)
            logger.debug("websocket event_sent type=%s", _safe_event_type(event_data))
        except Exception:
            logger.error("websocket send_failed type=%s", _safe_event_type(event_data))

    def _parse_event_data(self, event_data: dict) -> dict:
        """
        이벤트 데이터를 파싱하여 JSON 형식으로 변환합니다.
        """
        try:
            event_data["data"] = json.loads(event_data["data"])
        except json.JSONDecodeError:
            logger.warning("websocket decode_failed type=%s", _safe_event_type(event_data))
        return event_data
