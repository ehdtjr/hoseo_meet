from aioredis import ConnectionPool, Redis

from app.core.config import settings


class RedisClient:
    def __init__(self):
        self.redis = None
        self.pool = None

    async def get_connection(self) -> Redis:
        if not self.redis:
            if not self.pool:
                self.pool = ConnectionPool.from_url(
                    f"redis://{settings.REDIS_HOST}:{settings.REDIS_PORT}",
                    max_connections=10,
                    encoding="utf-8",
                    decode_responses=True,
                )
            self.redis = Redis(connection_pool=self.pool)
        return self.redis

    async def close_connection(self):
        if self.redis:
            await self.redis.close()
            self.redis = None
        if self.pool:
            await self.pool.disconnect()


redis_client = RedisClient()
