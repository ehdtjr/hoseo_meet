from asyncio import Protocol
from dataclasses import dataclass

from firebase_admin import messaging

from app.schemas.event import EventBase
from app.schemas.message import MessageResponse
from app.service.event.fcm.event_fcm_registry import register_fcm_event_strategy
from app.celery.event_fcm_task import send_multicast_task



@dataclass
class FCMEventSelectionContext:
    token_id: str
    event: EventBase


@dataclass
class FCMEventsSelectionContext:
    token_ids: list[str]
    event: EventBase


class FCMEventStrategyProtocol(Protocol):
    def send_notification(self, context: FCMEventSelectionContext):
        pass

    def sends_notifications(self, context: FCMEventsSelectionContext):
        pass


@register_fcm_event_strategy("stream")
class ChatMessageFCMEventStrategy(FCMEventStrategyProtocol):
    def send_notification(self, context: FCMEventSelectionContext,):
        print("[DEBUG] Entering ChatMessageFCMEventStrategy.send_notification")
        try:
            print("[DEBUG] Before calling messaging.send")

            # 1) Pydantic 모델 역직렬화
            message_model = MessageResponse.model_validate_json(context.event.data)
            content = message_model.content

            data_dict = context.event.model_dump()

            for k, v in data_dict.items():
                data_dict[k] = str(v)

            # 2) FCM 메시지 생성
            message = messaging.Message(
                notification=messaging.Notification(
                    title="새로운 메시지",
                    body=content,
                ),
                token=context.token_id,
                data=data_dict
            )
            messaging.send(message)
            print("[DEBUG] After calling messaging.send")

        except Exception as e:
            print("[ERROR] Exception in ChatMessageFCMEventStrategy:", e)
            raise e

        print("[DEBUG] Exiting ChatMessageFCMEventStrategy.send_notification")

    def sends_notifications(self, context: FCMEventsSelectionContext):
        print(
            "[DEBUG] Entering ChatMessageFCMEventStrategy.sends_notifications (Direct FCM)")
        try:
            # 1) Pydantic 모델 역직렬화
            message_model = MessageResponse.model_validate_json(
                context.event.data)
            content = message_model.content

            # 2) FCM data 필드 구성 (문자열 변환)
            data_dict = context.event.model_dump()
            for k, v in data_dict.items():
                data_dict[k] = str(v)
            send_multicast_task.delay(context.token_ids, "새로운 메세지", content, data_dict)
        except Exception as e:
            print("[ERROR] in sends_notifications:", e)
            raise e

        print("[DEBUG] Exiting ChatMessageFCMEventStrategy.sends_notifications")
