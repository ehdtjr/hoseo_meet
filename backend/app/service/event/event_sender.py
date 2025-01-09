import asyncio
import logging
from typing import Optional

from app.core.redis import redis_client
from app.schemas.event import EventBase
from app.service.event.fcm.event_fcm_factory import FCMEventStrategyFactory
from app.service.event.fcm.event_fcm_strategy import FCMEventSelectionContext

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class EventSenderProtocol:
    async def send_event(self, user_id: int, event_data: EventBase):
        pass


class WebSocketEventSender(EventSenderProtocol):
    async def send_event(self, user_id: int, event_data: EventBase):
        if not event_data:
            raise ValueError("이벤트 데이터가 비어 있거나 유효하지 않습니다")
        await redis_client.redis.xadd(f"queue:{user_id}", event_data.model_dump())


class FCMEventSender(EventSenderProtocol):
    def __init__(self, fcm_token: Optional[str]):
        self.fcm_token = fcm_token

    async def send_event(self, user_id: int, event_data: EventBase):
        if not self.fcm_token:
            return

        strategy = FCMEventStrategyFactory.get_strategy(event_data.type, self.fcm_token)

        context = FCMEventSelectionContext(
            user_id=user_id,
            stream_id=event_data.stream_id,
            event=event_data
        )
        asyncio.create_task(
            asyncio.to_thread(strategy.send_notification,context)
        )


class NoopEventSender(EventSenderProtocol):
    async def send_event(self, user_id: int, event_data: EventBase):
        pass