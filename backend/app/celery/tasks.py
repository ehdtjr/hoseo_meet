import time

import redis

from app.celery.worker import app
from app.core.config import settings


# A publisher cannot run between this check and removal. UNLINK removes the key
# immediately and lets Redis reclaim a potentially large stream asynchronously.
_DELETE_IDLE_QUEUE = """
if redis.call('TYPE', KEYS[1]).ok ~= 'stream' then
    return 0
end
local info = redis.call('XINFO', 'STREAM', KEYS[1])
for i = 1, #info, 2 do
    if info[i] == 'last-generated-id' then
        local last_ms = tonumber(string.match(info[i + 1], '^(%d+)'))
        if last_ms < tonumber(ARGV[1]) then
            return redis.call('UNLINK', KEYS[1])
        end
        return 0
    end
end
return 0
"""


def get_sync_redis():
    return redis.Redis(host=settings.REDIS_HOST, port=settings.REDIS_PORT,
                       decode_responses=True)


@app.task
def run_garbage_collection():
    redis_client = get_sync_redis()
    garbage_collection(redis_client)


def garbage_collection(redis_client, timeout_secs: int = 60):
    """Remove streams idle for strictly longer than timeout_secs (not per-entry TTL)."""
    if timeout_secs < 0:
        raise ValueError("timeout_secs must be non-negative")

    cutoff_ms = int(time.time() * 1000) - timeout_secs * 1000
    delete_if_idle = redis_client.register_script(_DELETE_IDLE_QUEUE)
    for queue_key in redis_client.scan_iter(match="queue:*", count=100):
        delete_if_idle(keys=[queue_key], args=[cutoff_ms])

