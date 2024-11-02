from aioredis import Redis
from fastapi import Depends
from fastapi_users_db_sqlalchemy import SQLAlchemyUserDatabase
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_async_session
from app.core.redis import redis_client
from app.models.user import User, OAuthAccount


async def get_user_db(session: AsyncSession = Depends(get_async_session)):
    yield SQLAlchemyUserDatabase(session, User, OAuthAccount)


async def get_redis() -> Redis:
    return await redis_client.get_connection()
