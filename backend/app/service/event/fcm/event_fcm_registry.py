from tkinter import EventType

STRATEGY_FCM_EVENT_REGISTRY = {}


def register_fcm_event_strategy(event_type: EventType):
    """
    특정 event_type으로 FCM Strategy 클래스를 전역 레지스트리에 등록하는
    데코레이터
    """
    def decorator(cls):
        STRATEGY_FCM_EVENT_REGISTRY[event_type] = cls
        return cls
    return decorator
