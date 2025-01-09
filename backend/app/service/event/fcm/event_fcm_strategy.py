from asyncio import Protocol
from dataclasses import dataclass

from pyfcm import FCMNotification

from app.schemas.event import EventBase
from app.service.event.fcm.event_fcm_registry import register_fcm_event_strategy

fcm = FCMNotification(
    service_account_file="hoseo-meet-firebase-adminsdk-oswm2-1186906f2e.json",
    project_id="hoseo-meet-7918f"
)

@dataclass
class FCMEventSelectionContext:
    user_id: int
    event: EventBase


class FCMEventStrategyProtocol(Protocol):

    def __init__(self, fcm_token: str):
        self.fcm_token = fcm_token

    async def send_notification(self, context: FCMEventSelectionContext):
        pass


@register_fcm_event_strategy("stream")
class ChatMessageFCMEventStrategy(FCMEventStrategyProtocol):

    async def send_notification(self, context: FCMEventSelectionContext):
        print("ChatMessageFCMEventStrategy")
        fcm.notify(
            fcm_token=self.fcm_token,
            notification_title="새로운 메시지",
            notification_body=context.event.data.content,
            apns_config={
                "payload": {
                    "aps": {
                        "alert": {
                            "title": "새로운 메시지",
                            "body": context.event.data.content
                        },
                        "sound": "default"  # iOS 기본 사운드 설정
                    }
                }
            },
            data_payload=context.event.model_dump_json()
        )
