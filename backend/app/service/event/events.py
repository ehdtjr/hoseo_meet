# app/service/event_dispatcher.py
import logging

from fastapi.params import Depends

from app.service.event.event_registry import STRATEGY_REGISTRY
from app.service.event.event_strategy import EventStrategyProtocol
from app.service.stream import ActiveStreamServiceProtocol, \
    get_active_stream_service

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class EventStrategyFactory:
    def __init__(self, active_stream_service: ActiveStreamServiceProtocol):
        self.active_stream_service = active_stream_service

    def get_strategy(self, event_type: str) -> EventStrategyProtocol:
        strategy_class = STRATEGY_REGISTRY.get(event_type)
        if strategy_class is None:
            raise ValueError(f"Event type {event_type} is not supported.")

        return strategy_class(self.active_stream_service)


def get_event_strategy_factory(
    active_stream_service: ActiveStreamServiceProtocol = Depends(
        get_active_stream_service),
) -> EventStrategyFactory:
    return EventStrategyFactory(active_stream_service)