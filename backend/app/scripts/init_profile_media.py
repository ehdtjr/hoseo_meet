"""Add the upload registry to an existing DB without trusting legacy URLs."""
import asyncio

from app.core.db import engine
from app.models import ProfileMedia


async def main():
    try:
        async with engine.begin() as conn:
            await conn.run_sync(
                lambda sync_conn: ProfileMedia.__table__.create(sync_conn, checkfirst=True)
            )
    finally:
        await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
