"""Initialize an empty local DB; never import CSVs or modify existing users."""
import asyncio

from fastapi_users.password import PasswordHelper
from sqlalchemy import select, text

from app.core.config import settings
from app.core.db import Base, async_session_maker, engine
import app.models  # noqa: F401
import app.domains.restaurant.model  # noqa: F401
from app.models import User
from app.tests_pre_start import init as wait_for_database


async def main():
    if settings.ENVIRONMENT != "local":
        raise RuntimeError("Local initialization is only available in local environments")
    await wait_for_database(engine)
    async with engine.begin() as conn:
        await conn.execute(text("CREATE EXTENSION IF NOT EXISTS postgis"))
        await conn.run_sync(Base.metadata.create_all)
    async with async_session_maker() as db:
        for email, name, admin in (
            (settings.FIRST_SUPERUSER, "Local Admin", True),
            ("member@example.com", "Local Member", False),
        ):
            existing = (await db.execute(select(User).where(User.email == email))).unique().scalar_one_or_none()
            if existing is None:
                db.add(User(email=email, name=f"{name} ({email})", gender="male", is_active=True,
                            is_verified=True, is_superuser=admin,
                            hashed_password=PasswordHelper().hash(settings.FIRST_SUPERUSER_PASSWORD)))
        await db.commit()
    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
