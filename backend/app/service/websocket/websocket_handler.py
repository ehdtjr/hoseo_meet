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
logger.setLevel(logging.DEBUG)  # DEBUG 레벨로 설정하여 더 많은 로그 기록


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
        except Exception as e:
            logger.error(f"WebSocket 작업 중 예외 발생: {e}")
        finally:
            for task in tasks:
                task.cancel()  # 예외 발생 시 모든 태스크를 취소하여 안전하게 종료

            connected_websockets.dec()  # WebSocket 연결 해제 시 접속자 수 감소
            self.websocket_manager.disconnect(websocket)  # WebSocket 연결 해제
            logger.info(f"사용자 {user_id}의 연결이 종료되었습니다.")
            disconnect_event.set()  # 연결 종료 이벤트 설정


    async def _receive_from_redis(self, websocket: WebSocket, queue_key: str, disconnect_event: asyncio.Event):
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
            except (ConnectionClosedError, ConnectionClosedOK, WebSocketDisconnect) as e:
                logger.info(f"WebSocket 연결이 닫힘: {e}")
                disconnect_event.set()
                raise e
            except ServerConnectionError as e:
                logger.error(f"Redis 서버 연결 오류: {e}")
                disconnect_event.set()
                raise e
            except Exception as e:
                logger.error(f"예상치 못한 오류 발생: {e}")
                disconnect_event.set()
                raise e
        await pool.close()
        logger.info("pool 종료: Redis 연결이 안전하게 종료되었습니다.")

    async def _receive_ws_messages(self, websocket: WebSocket, disconnect_event: asyncio.Event):
        """
        WebSocket 클라이언트로부터 수신을 처리하고, 종료 시 이벤트를 설정합니다.
        """
        while not disconnect_event.is_set():
            try:
                message = await websocket.receive_text()
                logger.debug(f"WebSocket에서 수신한 메시지: {message}")
            except (ConnectionClosedError, ConnectionClosedOK, WebSocketDisconnect) as e:
                logger.info(f"WebSocket receive 연결 종료: {e}")
                raise e
            except Exception as e:
                logger.error(f"WebSocket receive에서 예외 발생: {e}")
                raise e
            finally:
                disconnect_event.set()

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
            logger.debug(f"WebSocket으로 이벤트 전송: {event_data_json}")
        except Exception as e:
            logger.error(f"이벤트 전송 중 예외 발생: {e}")

    def _parse_event_data(self, event_data: dict) -> dict:
        """
        이벤트 데이터를 파싱하여 JSON 형식으로 변환합니다.
        """
        try:
            event_data["data"] = json.loads(event_data["data"])
        except json.JSONDecodeError:
            logger.warning(f"JSON 파싱 실패: {event_data}")
        return event_data
