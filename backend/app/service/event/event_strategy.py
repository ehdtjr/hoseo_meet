from asyncio import Protocol
from dataclasses import dataclass

from sqlmodel.ext.asyncio.session import AsyncSession

from app.crud.user_crud import get_user_fcm_token_crud
from app.schemas.event import EventBase
from app.schemas.user import UserFCMTokenBase
from app.service.event.event_registry import register_strategy
from app.service.event.event_sender import WebSocketEventSender, FCMEventSender, \
    NoopEventSender, EventSenderProtocol
from app.service.stream import ActiveStreamServiceProtocol


@dataclass
class SenderSelectionContext:
    user_id: int
    stream_id: int
    event: EventBase


class EventStrategyProtocol(Protocol):
    """
    이벤트 타입 별로, 어떤 Sender를 반환할지 정하는 전략을 정의한 프로토콜
    """

    async def get_sender(self,
                         db: AsyncSession,
                         context: SenderSelectionContext) -> \
            EventSenderProtocol:
        pass


@register_strategy("stream")
class ChatMessageEventStrategy(EventStrategyProtocol):
    """
    채팅 메시지 이벤트에 대한 전략
    """

    def __init__(self, active_stream_service: ActiveStreamServiceProtocol):
        self.active_stream_service = active_stream_service

    async def get_sender(self, db: AsyncSession,
    context:SenderSelectionContext) -> EventSenderProtocol:
        active_stream_id = await self.active_stream_service.get_active_stream(context.user_id)
        if active_stream_id == context.stream_id:
            return WebSocketEventSender()
        else:
            user_fcm_crud = get_user_fcm_token_crud()
            user_fcm_data: UserFCMTokenBase = await (
            user_fcm_crud.get_user_fcm_token_by_user_id(db, context.user_id))
            fcm_token = user_fcm_data.fcm_token if user_fcm_data else None
            return FCMEventSender(fcm_token)


@register_strategy("location")
class LocationEventStrategy(EventStrategyProtocol):
    """
    위치 이벤트에 대한 전략
    """
    def __init__(self, active_stream_service: ActiveStreamServiceProtocol):
        self.active_stream_service = active_stream_service

    async def get_sender(self, db: AsyncSession,
    context:SenderSelectionContext) -> EventSenderProtocol:
        active_stream_id = await self.active_stream_service.get_active_stream(context.user_id)
        if active_stream_id == context.stream_id:
            return WebSocketEventSender()
        else:
            return NoopEventSender()


@register_strategy("read")
class ReadMessageEventStrategy(EventStrategyProtocol):
    """
    읽음 이벤트에 대한 전략
    """
    def __init__(self, active_stream_service: ActiveStreamServiceProtocol):
        self.active_stream_service = active_stream_service

    async def get_sender(self, db: AsyncSession,
                         context:SenderSelectionContext) -> EventSenderProtocol:
        active_stream_id = await (
            self.active_stream_service.get_active_stream(context.user_id))
        if active_stream_id == context.stream_id:
            return WebSocketEventSender()
        else:
            return NoopEventSender()