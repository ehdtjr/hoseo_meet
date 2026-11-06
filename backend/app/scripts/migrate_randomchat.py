"""Add the random-chat queue table to an existing initialized database.

Run before deploying the matching API; repeat runs preserve existing data.
There is no versioned Alembic baseline in this repository yet.
"""
import asyncio

from app.core.db import engine
from app.models import RandomChatQueue


async def main():
    async with engine.begin() as connection:
        await connection.run_sync(
            lambda conn: RandomChatQueue.__table__.create(conn, checkfirst=True)
        )
    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
