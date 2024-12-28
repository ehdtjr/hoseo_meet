# event_registry.py
STRATEGY_REGISTRY = {}


def register_strategy(event_type: str):
    """
    특정 event_type으로 Strategy 클래스를 전역 레지스트리에 등록하는
    데코레이터
    """
    def decorator(cls):
        STRATEGY_REGISTRY[event_type] = cls
        return cls
    return decorator
