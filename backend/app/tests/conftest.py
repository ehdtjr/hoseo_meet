from typing import AsyncGenerator
from unittest.async_case import IsolatedAsyncioTestCase

from sqlalchemy import NullPool
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, \
    async_sessionmaker

from app.main import app
from app.core.db import Base, get_async_session


SQLALCHEMY_TEST_DATABASE_URL = "postgresql+asyncpg://test_user:test_password@localhost:5433/test_db"

test_engine = create_async_engine(SQLALCHEMY_TEST_DATABASE_URL,
                                  poolclass=NullPool)
TestSessionLocal = async_sessionmaker(autocommit=False, autoflush=False,
                                      bind=test_engine)


async def override_get_db() -> AsyncGenerator[AsyncSession, None]:
    async with TestSessionLocal() as session:
        yield session


class BaseTest(IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.db_gen = override_get_db()
        self.db = await self.db_gen.__anext__()

        app.dependency_overrides[get_async_session] = override_get_db
        # Create tables
        async with test_engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

    async def asyncTearDown(self):
        await self.db.rollback()
        await self.db.close()
        await self.db_gen.aclose()

        # Drop tables
        async with test_engine.begin() as conn:
            await conn.run_sync(Base.metadata.drop_all)

        dependency_overrides = {}