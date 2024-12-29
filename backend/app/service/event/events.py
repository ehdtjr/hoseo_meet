import logging
from typing import List

from fastapi.params import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.event import EventBase
from app.service.event.event_registry import STRATEGY_EVENT_REGISTRY
from app.service.event.event_sender import EventSenderProtocol
from app.service.event.event_strategy import EventStrategyProtocol, \
    SenderSelectionContext
from app.service.stream import ActiveStreamServiceProtocol, \
    get_active_stream_service

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class EventStrategyFactory:
    def __init__(self, active_stream_service: ActiveStreamServiceProtocol):
        self.active_stream_service = active_stream_service

    def get_strategy(self, event_type: str) -> EventStrategyProtocol:
        strategy_class = STRATEGY_EVENT_REGISTRY.get(event_type)
        if strategy_class is None:
            raise ValueError(f"Event type {event_type} is not supported.")

        return strategy_class(self.active_stream_service)


def get_event_strategy_factory(
    active_stream_service: ActiveStreamServiceProtocol = Depends(
        get_active_stream_service),
) -> EventStrategyFactory:
    return EventStrategyFactory(active_stream_service)


class EventDispatcher:
    def __init__(self, event_strategy_factory: EventStrategyFactory):
        self.event_strategy_factory = event_strategy_factory

    async def dispatch(
        self,
        db: AsyncSession,
        user_ids: List[int],
        stream_id: int,
        event_data: EventBase
    ) -> None:
        """
        주어진 user_ids에게 event_data(이벤트)를 전송한다.
        event_strategy_factory를 통해 적절한 전략(Strategy)을 선택하고,
        Sender를 생성하여 이벤트를 발송한다.
        """
        for user_id in user_ids:
            context = SenderSelectionContext(
                user_id=user_id,
                stream_id=stream_id,
                event=event_data
            )
            strategy = self.event_strategy_factory.get_strategy(event_data.type)
            event_sender: EventSenderProtocol = await strategy.get_sender(db, context)
            await event_sender.send_event(user_id=user_id, event_data=event_data)


def get_event_dispatcher(
    event_strategy_factory: EventStrategyFactory = Depends(
        get_event_strategy_factory),
) -> EventDispatcher:
    return EventDispatcher(event_strategy_factory)