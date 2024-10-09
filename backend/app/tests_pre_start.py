import asyncio
import logging
from sqlalchemy.ext.asyncio import AsyncEngine
from sqlalchemy import text
from tenacity import after_log, before_log, retry, stop_after_attempt, wait_fixed

from app.core.db import engine, async_session_maker

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

max_tries = 60  # 1 minute
wait_seconds = 1


@retry(
    stop=stop_after_attempt(max_tries),
    wait=wait_fixed(wait_seconds),
    before=before_log(logger, logging.INFO),
    after=after_log(logger, logging.WARN),
)
async def init(db_engine: AsyncEngine) -> None:
    try:
        async with async_session_maker() as session:
            async with session.begin():
                await session.execute(text("SELECT 1"))
    except Exception as e:
        logger.error(f"Database connection error: {str(e)}")
        raise e


async def main() -> None:
    logger.info("Initializing service")
    await init(engine)
    logger.info("Service finished initializing")


if __name__ == "__main__":
    asyncio.run(main())
