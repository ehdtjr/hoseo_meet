import json

from aioredis import Redis


# 이벤트 전송 함수
async def send_event(redis: Redis, user_id: int, event_data: dict):
    if not event_data:
        raise ValueError("Event data is empty or invalid")
    event_data = json.dumps(event_data, ensure_ascii=False)
    await redis.xadd(f"queue:{user_id}", {"data": event_data})
