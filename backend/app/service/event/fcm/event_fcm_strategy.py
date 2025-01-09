from asyncio import Protocol
from dataclasses import dataclass
import json
from pyfcm import FCMNotification

from app.schemas.event import EventBase
from app.schemas.message import MessageResponse
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
    def send_notification(self, context: FCMEventSelectionContext):
        print("[DEBUG] Entering ChatMessageFCMEventStrategy.send_notification")
        try:
            print("[DEBUG] Before calling fcm.notify")

            # 1) Pydantic 모델 역직렬화
            message_model = MessageResponse.model_validate_json(context.event.data)
            content = message_model.content

            #    다만 이 결과는 'JSON 문자열'이므로, data_payload에 딕셔너리를 주려면 json.loads()를 해야 한다.
            data_dict = json.loads(message_model.model_dump_json())

            # 3) FCM 전송
            fcm.notify(
                fcm_token=self.fcm_token,
                notification_title="새로운 메시지",
                notification_body=content,
                apns_config={
                    "payload": {
                        "aps": {
                            "alert": {
                                "title": "새로운 메시지",
                                "body": content
                            },
                            "sound": "default"
                        }
                    }
                },
                data_payload=data_dict
            )

            print("[DEBUG] After calling fcm.notify")

        except Exception as e:
            print("[ERROR] Exception in ChatMessageFCMEventStrategy:", e)
            raise e

        print("[DEBUG] Exiting ChatMessageFCMEventStrategy.send_notification")
