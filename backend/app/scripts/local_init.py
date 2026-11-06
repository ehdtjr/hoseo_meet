"""Upgrade a local DB to the tracked schema and seed synthetic users."""

import asyncio
from pathlib import Path

from alembic import command
from alembic.config import Config
from fastapi_users.password import PasswordHelper
from sqlalchemy import select

import app.domains.restaurant.model  # noqa: F401
import app.models  # noqa: F401
from app.core.config import settings
from app.core.db import async_session_maker, engine
from app.models import User
from app.tests_pre_start import init as wait_for_database


def upgrade_database() -> None:
    """Apply every tracked revision to the configured local database."""
    config_path = Path(settings.BASE_DIR).parent / "alembic.ini"
    alembic_config = Config(str(config_path))
    command.upgrade(alembic_config, "head")


async def main():
    if settings.ENVIRONMENT != "local":
        raise RuntimeError(
            "Local initialization is only available in local environments"
        )
    try:
        await wait_for_database(engine)
        # Alembic's async environment owns its event loop, so run it off this loop.
        await asyncio.to_thread(upgrade_database)
        async with async_session_maker() as db:
            for email, name, admin in (
                (settings.FIRST_SUPERUSER, "Local Admin", True),
                ("member@example.com", "Local Member", False),
            ):
                existing = (
                    (await db.execute(select(User).where(User.email == email)))
                    .unique()
                    .scalar_one_or_none()
                )
                if existing is None:
                    db.add(
                        User(
                            email=email,
                            name=f"{name} ({email})",
                            gender="male",
                            is_active=True,
                            is_verified=True,
                            is_superuser=admin,
                            hashed_password=PasswordHelper().hash(
                                settings.FIRST_SUPERUSER_PASSWORD
                            ),
                        )
                    )
            await db.commit()
    finally:
        await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
