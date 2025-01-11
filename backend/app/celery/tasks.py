import time

import redis

from app.celery.worker import app
from app.core.config import settings


def get_sync_redis():
    return redis.Redis(host=settings.REDIS_HOST, port=settings.REDIS_PORT,
                       decode_responses=True)


@app.task
def run_garbage_collection():
    redis_client = get_sync_redis()
    garbage_collection(redis_client)


def garbage_collection(redis_client, timeout_secs: int = 60):
    queue_keys = redis_client.keys("queue:*")
    current_time_ms = int(time.time() * 1000)

    for queue_key in queue_keys:
        queue_info = redis_client.xinfo_stream(queue_key)
        if not queue_info:
            continue

        last_event_id = queue_info.get("last-generated-id", None)
        if last_event_id:
            last_event_id = int(last_event_id.split("-")[0])
            if current_time_ms - last_event_id > timeout_secs * 1000:
                redis_client.delete(queue_key)
        else:
            redis_client.delete(queue_key)