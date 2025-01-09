from app.service.event.fcm.event_fcm_registry import STRATEGY_FCM_EVENT_REGISTRY
from app.service.event.fcm.event_fcm_strategy import FCMEventStrategyProtocol


class FCMEventStrategyFactory:

    @staticmethod
    def get_strategy(event_type: str, fcm_token: str) -> (
            FCMEventStrategyProtocol):
        strategy_class = STRATEGY_FCM_EVENT_REGISTRY.get(event_type)
        if strategy_class is None:
            raise ValueError(f"Event type {event_type} is not supported.")
        return strategy_class(fcm_token)
