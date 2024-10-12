import json
import logging

from aioredis import Redis

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# 이벤트 전송 함수
async def send_event(redis: Redis, user_id: int, event_data: dict):
    if not event_data:
        raise ValueError("Event data is empty or invalid")
    event_data = json.dumps(event_data, ensure_ascii=False)
    await redis.xadd(f"queue:{user_id}", {"data": event_data})


async def send_event_fcm():
    pass


async def send_event_websocket():
    pass
