# app/service/event_dispatcher.py
import logging
from typing import Dict

from fastapi.params import Depends

from app.service.event.event_strategy import (
    EventStrategyProtocol,
    ChatMessageEventStrategy,
    LocationEventStrategy, )
from app.service.stream import ActiveStreamServiceProtocol, \
    get_active_stream_service

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class EventStrategyFactory:
    def __init__(self, active_stream_service: ActiveStreamServiceProtocol):
        self.active_stream_service = active_stream_service
        self.strategies: Dict[str, EventStrategyProtocol] = {
            "stream": ChatMessageEventStrategy(active_stream_service),
            "location": LocationEventStrategy(active_stream_service),
        }

    def get_strategy(self, event_type: str) -> EventStrategyProtocol:
        if event_type not in self.strategies:
            raise ValueError(f"Event type {event_type} is not supported")
        return self.strategies.get(event_type)


def get_event_strategy_factory(
    active_stream_service: ActiveStreamServiceProtocol = Depends(get_active_stream_service),
) -> (
EventStrategyFactory):
    return EventStrategyFactory(active_stream_service)