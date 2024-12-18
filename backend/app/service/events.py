import asyncio
import json
import logging
from typing import Optional
from dataclasses import dataclass

from pyfcm import FCMNotification
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.redis import redis_client
from app.crud.user_crud import get_user_fcm_token_crud
from app.schemas.event import EventBase
from app.schemas.user import UserFCMTokenBase
from app.service.stream import ActiveStreamServiceProtocol, get_active_stream_service

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

fcm = FCMNotification(
    service_account_file="hoseo-meet-firebase-adminsdk-oswm2-1186906f2e.json",
    project_id="hoseo-meet-7918f"
)

@dataclass
class SenderSelectionContext:
    user_id: int
    stream_id: int

class EventSenderProtocol:
    async def send_event(self, user_id: int, event_data: EventBase):
        pass

class WebSocketEventSender(EventSenderProtocol):
    async def send_event(self, user_id: int, event_data: EventBase):
        if not event_data:
            raise ValueError("이벤트 데이터가 비어 있거나 유효하지 않습니다")
        await redis_client.redis.xadd(f"queue:{user_id}", event_data.to_str_dict())

class FCMEventSender(EventSenderProtocol):
    def __init__(self, fcm_token: Optional[str]):
        self.fcm_token = fcm_token

    async def send_event(self, user_id: int, event_data: EventBase):
        if not self.fcm_token:
            return
        data_dict = event_data.dict() if hasattr(event_data, "dict") else {"event": str(event_data)}
        await asyncio.to_thread(self._send_fcm_notification, user_id=user_id, event_data=data_dict)

    def _send_fcm_notification(self, user_id: int, event_data: dict):
        try:
            fcm.notify(
                fcm_token=self.fcm_token,
                notification_title="새로운 메시지",
                notification_body=json.dumps(event_data, ensure_ascii=False)
            )
            logger.info(f"사용자 {user_id}에게 FCM 알림이 전송되었습니다.")
        except Exception as e:
            logger.error(f"FCM 알림 전송 실패: {e}")

class EventDispatcher:
    def __init__(self, user_id: int, event_sender: EventSenderProtocol):
        self.user_id = user_id
        self.event_sender = event_sender

    async def send_event(self, event_data: EventBase):
        await self.event_sender.send_event(user_id=self.user_id, event_data=event_data)

class EventSenderSelectorProtocol:
    async def select_event_sender(self, db: AsyncSession, context: SenderSelectionContext) -> EventSenderProtocol:
        pass

class ActiveStreamEventSenderSelector(EventSenderSelectorProtocol):
    def __init__(self, active_stream_service: ActiveStreamServiceProtocol):
        self.active_stream_service = active_stream_service

    async def select_event_sender(self, db: AsyncSession, context: SenderSelectionContext) -> EventSenderProtocol:
        active_stream_id = await self.active_stream_service.get_active_stream(context.user_id)
        if active_stream_id == context.stream_id:
            return WebSocketEventSender()
        else:
            user_fcm_crud = get_user_fcm_token_crud()
            user_fcm_data: UserFCMTokenBase = await user_fcm_crud.get_user_fcm_token_by_user_id(db, context.user_id)
            fcm_token = user_fcm_data.fcm_token if user_fcm_data else None
            return FCMEventSender(fcm_token)

async def create_event_dispatcher(
    db: AsyncSession,
    context: SenderSelectionContext,
    selector: EventSenderSelectorProtocol = ActiveStreamEventSenderSelector(get_active_stream_service())
) -> EventDispatcher:
    sender = await selector.select_event_sender(db, context)
    return EventDispatcher(context.user_id, sender)
