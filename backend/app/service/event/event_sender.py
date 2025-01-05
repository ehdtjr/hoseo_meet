import logging
from typing import Optional

import asyncio
from pyfcm import FCMNotification

from app.core.redis import redis_client
from app.schemas.event import EventBase

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


fcm = FCMNotification(
    service_account_file="hoseo-meet-firebase-adminsdk-oswm2-1186906f2e.json",
    project_id="hoseo-meet-7918f"
)


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
        # FCM 토큰이 없다면, 푸시 알림을 보낼 수 없으므로 종료
        if not self.fcm_token:
            return

        if hasattr(event_data, "model_dump"):
            data_dict = event_data.model_dump()
        else:
            data_dict = {"event": str(event_data)}

        await asyncio.to_thread(self._send_fcm_notification, event_data=data_dict)

    def _send_fcm_notification(self, event_data: dict):
        try:
            import json
            fcm.notify(
                fcm_token=self.fcm_token,
                notification_title="새로운 메시지",
                notification_body=json.dumps(event_data, ensure_ascii=False),
                apns_config={
                    "payload": {
                        "aps": {
                            "alert": {
                                "title": "새로운 메시지",
                                "body": json.dumps(event_data,
                                                   ensure_ascii=False)
                            },
                            "sound": "default"  # iOS 기본 사운드 설정
                        }
                    }
                }
            )
        except Exception as e:
            logger.error(f"FCM 알림 전송 실패: {e}")


class NoopEventSender(EventSenderProtocol):
    async def send_event(self, user_id: int, event_data: EventBase):
        pass