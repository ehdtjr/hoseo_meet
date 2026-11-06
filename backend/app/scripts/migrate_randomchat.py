"""Legacy queue repair helper retained for pre-adoption reconciliation only.

Normal installations and upgrades use Alembic. Unversioned databases must
pass app.scripts.adopt_legacy_db before upgrading. Use this helper only for a
reviewed missing queue table with a verified backup and writers stopped; it
does not validate or stamp the complete application schema.
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
