from asyncio import Protocol
from dataclasses import dataclass
from typing import List, Optional, Dict

from sqlmodel.ext.asyncio.session import AsyncSession

from app.schemas.event import EventBase
from app.service.event.event_registry import register_event_strategy
from app.service.event.event_sender import (
    WebSocketEventSender,
    FCMEventSender,
    NoopEventSender,
    EventSenderProtocol,
)
from app.service.stream import ActiveStreamServiceProtocol


# ----------------------------------------------------
# (1) 그룹 정보 구조체: Sender + 해당 유저들
# ----------------------------------------------------
@dataclass
class SenderUsersGroup:
    sender: EventSenderProtocol
    user_ids: List[int]


# ----------------------------------------------------
# (2) 기존 Context 데이터 클래스 (유지)
# ----------------------------------------------------
@dataclass
class SenderSelectionContext:
    user_id: int
    stream_id: int
    event: EventBase


@dataclass
class SendersSelectionContext:
    user_ids: list[int]
    stream_id: int
    event: EventBase


# ----------------------------------------------------
# (3) EventStrategy 프로토콜
#     - 단일 유저(get_sender)
#     - 다중 유저(get_senders) → 반환 타입 수정
# ----------------------------------------------------
class EventStrategyProtocol(Protocol):
    """
    이벤트 타입 별로, 어떤 Sender를 반환할지 정하는 전략을 정의한 프로토콜
    """

    async def get_sender(
        self,
        db: AsyncSession,
        context: SenderSelectionContext
    ) -> EventSenderProtocol:
        """
        단일 사용자에게 이벤트를 보낼 때 필요한 Sender를 결정
        """
        pass

    async def get_senders(
        self,
        db: AsyncSession,
        context: SendersSelectionContext
    ) -> List[SenderUsersGroup]:
        """
        다중 사용자에게 이벤트를 보낼 때 필요한 Sender + user_ids 묶음을 반환
        """
        pass


# ----------------------------------------------------
# (4) ChatMessageEventStrategy (stream)
#     - WebSocket vs FCM 분류
# ----------------------------------------------------
@register_event_strategy("stream")
class ChatMessageEventStrategy(EventStrategyProtocol):
    """
    채팅 메시지 이벤트에 대한 전략
    """
    def __init__(self, active_stream_service: ActiveStreamServiceProtocol):
        self.active_stream_service = active_stream_service

    async def get_sender(
        self,
        db: AsyncSession,
        context: SenderSelectionContext
    ) -> EventSenderProtocol:
        # 단일 사용자 로직
        active_stream_id = await self.active_stream_service.get_active_stream(context.user_id)

        if active_stream_id == context.stream_id:
            return WebSocketEventSender()
        else:
            return FCMEventSender()

    async def get_senders(
        self,
        db: AsyncSession,
        context: SendersSelectionContext
    ) -> List[SenderUsersGroup]:

        active_stream_ids: Dict[int, Optional[int]] = await (
            self.active_stream_service.get_active_stream_user_ids(context.user_ids)
        )

        # 1) 웹소켓 보낼 유저 vs FCM 보낼 유저 분류
        ws_users = []
        fcm_users = []
        for user_id in context.user_ids:
            active_stream_id = active_stream_ids.get(user_id)
            if active_stream_id == context.stream_id:
                ws_users.append(user_id)
            else:
                fcm_users.append(user_id)

        # 2) 그룹 별로 SenderUsersGroup 생성
        result: List[SenderUsersGroup] = []
        if ws_users:
            result.append(SenderUsersGroup(sender=WebSocketEventSender(), user_ids=ws_users))
        if fcm_users:
            result.append(SenderUsersGroup(sender=FCMEventSender(), user_ids=fcm_users))

        return result


# ----------------------------------------------------
# (5) LocationEventStrategy (location)
#     - WebSocket vs Noop 분류
# ----------------------------------------------------
@register_event_strategy("location")
class LocationEventStrategy(EventStrategyProtocol):
    """
    위치 이벤트에 대한 전략
    """
    def __init__(self, active_stream_service: ActiveStreamServiceProtocol):
        self.active_stream_service = active_stream_service

    async def get_sender(
        self,
        db: AsyncSession,
        context: SenderSelectionContext
    ) -> EventSenderProtocol:
        # 단일 사용자 로직
        active_stream_id = await self.active_stream_service.get_active_stream(context.user_id)
        if active_stream_id == context.stream_id:
            return WebSocketEventSender()
        else:
            return NoopEventSender()

    async def get_senders(
        self,
        db: AsyncSession,
        context: SendersSelectionContext
    ) -> List[SenderUsersGroup]:

        active_stream_ids: Dict[int, Optional[int]] = await (
            self.active_stream_service.get_active_stream_user_ids(context.user_ids)
        )

        # WebSocket vs Noop
        ws_users = []
        noop_users = []
        for user_id in context.user_ids:
            active_stream_id = active_stream_ids.get(user_id)
            if active_stream_id == context.stream_id:
                ws_users.append(user_id)
            else:
                noop_users.append(user_id)

        groups: List[SenderUsersGroup] = []
        if ws_users:
            groups.append(SenderUsersGroup(sender=WebSocketEventSender(), user_ids=ws_users))
        if noop_users:
            groups.append(SenderUsersGroup(sender=NoopEventSender(), user_ids=noop_users))

        return groups


# ----------------------------------------------------
# (6) ReadMessageEventStrategy (read)
#     - WebSocket vs Noop 분류
# ----------------------------------------------------
@register_event_strategy("read")
class ReadMessageEventStrategy(EventStrategyProtocol):
    """
    읽음 이벤트에 대한 전략
    """
    def __init__(self, active_stream_service: ActiveStreamServiceProtocol):
        self.active_stream_service = active_stream_service

    async def get_sender(
        self,
        db: AsyncSession,
        context: SenderSelectionContext
    ) -> EventSenderProtocol:
        # 단일 사용자 로직
        active_stream_id = await self.active_stream_service.get_active_stream(context.user_id)
        if active_stream_id == context.stream_id:
            return WebSocketEventSender()
        else:
            return NoopEventSender()

    async def get_senders(
        self,
        db: AsyncSession,
        context: SendersSelectionContext
    ) -> List[SenderUsersGroup]:

        active_stream_ids: Dict[int, Optional[int]] = await (
            self.active_stream_service.get_active_stream_user_ids(context.user_ids)
        )

        ws_users = []
        noop_users = []
        for user_id in context.user_ids:
            active_stream_id = active_stream_ids.get(user_id)
            if active_stream_id == context.stream_id:
                ws_users.append(user_id)
            else:
                noop_users.append(user_id)

        result: List[SenderUsersGroup] = []
        if ws_users:
            result.append(SenderUsersGroup(sender=WebSocketEventSender(), user_ids=ws_users))
        if noop_users:
            result.append(SenderUsersGroup(sender=NoopEventSender(), user_ids=noop_users))
        return result
