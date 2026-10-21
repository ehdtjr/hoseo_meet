from contextlib import asynccontextmanager
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import (AsyncAttrs, AsyncSession,
                                    async_sessionmaker, \
                                    create_async_engine)
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings

import logging
from sqlalchemy import event
from sqlalchemy import Pool

logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@event.listens_for(Pool, 'connect')
def receive_connect(dbapi_connection, connection_record):
    logger.info(f"New DB connection created - id: {id(dbapi_connection)}")

@event.listens_for(Pool, 'checkout')
def receive_checkout(dbapi_connection, connection_record, connection_proxy):
    logger.info(f"DB connection checked out - id: {id(dbapi_connection)}")

@event.listens_for(Pool, 'checkin')
def receive_checkin(dbapi_connection, connection_record):
    logger.info(f"DB connection returned to pool - id: {id(dbapi_connection)}")

engine = create_async_engine(
    str(settings.SQLALCHEMY_DATABASE_URI),
)

async_session_maker = async_sessionmaker(engine, expire_on_commit=False)


################################################################


async def get_async_session() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_maker() as session:
        yield session


@asynccontextmanager
async def get_async_session_context() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_maker() as session:
        try:
            yield session
        except Exception as e:
            await session.rollback()
            raise
        finally:
            await session.close()

class Base(AsyncAttrs, DeclarativeBase):
    pass