import asyncio
import logging
from datetime import datetime, timezone

from sqlalchemy import delete

from app.celery.db import sync_session_maker
from app.celery.worker import app
from app.models import StoryPost
from app.scripts.collect_story_media import run


@app.task
def delete_expired_story_posts_task():
    with sync_session_maker() as session:
        try:
            now = datetime.now(timezone.utc)
            logger = logging.getLogger(__name__)
            logger.info(f"Deleting expired story posts at: {now}")
            stmt = delete(StoryPost).where(StoryPost.expires_at <= now)
            session.execute(stmt)
            session.commit()
        except Exception as e:
            logger.error(f"Error deleting expired story posts: {e}")
            session.rollback()
            raise

    # The story transaction is committed before touching storage. Streams,
    # recipients, messages and subscriptions deliberately survive expiration.
    # Fresh engine per task avoids sharing async pools across asyncio.run loops.
    asyncio.run(run(apply=True))
