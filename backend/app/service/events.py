import asyncio
import json
import logging

from pyfcm import FCMNotification
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.redis import redis_client
from app.crud.user_crud import get_user_fcm_token_crud
from app.schemas.event import EventBase
from app.schemas.user import UserFCMTokenBase, UserRead

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

fcm = FCMNotification(service_account_file="hoseo-meet-firebase-adminsdk"
                                           "-oswm2-1186906f2e.json",
                                            project_id="hoseo-meet-7918f")

class EventSenderProtocol:
    """다양한 채널을 통해 이벤트를 전송하기 위한 프로토콜"""
    async def send_event(self,
        user_id: int,
        event_data: EventBase):
        pass

class WebSocketEventSender(EventSenderProtocol):
    """Redis 스트림을 사용하여 WebSocket을 통해 이벤트를 전송하는 클래스"""
    async def send_event(self, user_id: int, event_data: EventBase):
        if not event_data:
            raise ValueError("이벤트 데이터가 비어 있거나 유효하지 않습니다")
        await redis_client.redis.xadd(f"queue:{user_id}", event_data.to_str_dict())

class FCMEventSender(EventSenderProtocol):
    """Firebase Cloud Messaging (FCM)을 통해 이벤트를 전송하는 클래스"""
    def __init__(self, fcm_token: str):
        self.fcm_token = fcm_token

    async def send_event(self, user_id: int, event_data: dict):
        if not self.fcm_token:
            return
        await asyncio.to_thread(self._send_fcm_notification, user_id=user_id, event_data=event_data)

    def _send_fcm_notification(self, user_id: int, event_data: dict):
        """FCM을 사용하여 알림을 전송"""
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
    """적절한 전송자를 통해 이벤트를 전송하는 클래스"""
    def __init__(self, user_id: int, event_sender: EventSenderProtocol):
        self.user_id = user_id
        self.event_sender = event_sender

    async def send_event(self, event_data: EventBase):
        """선택된 전송자를 사용하여 이벤트를 전송"""
        await self.event_sender.send_event(
            user_id=self.user_id,
            event_data=event_data
        )

async def create_event_dispatcher(
        db: AsyncSession,
        user: UserRead
) -> EventDispatcher:
    """사용자의 온라인 상태에 따라 EventDispatcher 인스턴스를 생성하는 팩토리 함수"""
    # if user.is_online:
    sender: EventSenderProtocol = WebSocketEventSender()
    # else:
    #     user_fcm_crud = get_user_fcm_token_crud()
    #     user_fcm_data: UserFCMTokenBase = await user_fcm_crud.get_user_fcm_token_by_user_id(db, user.id)
    #     fcm_token = user_fcm_data.fcm_token if user_fcm_data else None
    #     sender: EventSenderProtocol = FCMEventSender(fcm_token)

    return EventDispatcher(user.id, sender)

