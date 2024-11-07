from contextlib import asynccontextmanager
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import (AsyncAttrs, AsyncSession,
                                    async_sessionmaker, \
                                    create_async_engine)
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings

engine = create_async_engine(
    str(settings.SQLALCHEMY_DATABASE_URI),
   # echo=True,
   # echo_pool=True
)
async_session_maker = async_sessionmaker(engine, expire_on_commit=False)


################################################################


async def get_async_session() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_maker() as session:
        try:
            yield session
        except Exception as e:
            await session.rollback()
            raise
        finally:
            await session.close()


from app.main import logger


@asynccontextmanager
async def get_async_session_context() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_maker() as session:
        try:
            logger.info("Session opened")
            yield session
        except Exception as e:
            await session.rollback()
            logger.error(f"Session rollback due to error: {e}")
            raise
        finally:
            await session.close()
            logger.info("Session closed")

class Base(AsyncAttrs, DeclarativeBase):
    pass
