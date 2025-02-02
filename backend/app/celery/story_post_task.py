from datetime import datetime, timezone

from asgiref.sync import async_to_sync
from sqlalchemy import delete

from app.celery.worker import app
from app.core.db import async_session_maker
from app.models import StoryPost


async def _delete_expired_story_posts():
    try:
        async with async_session_maker() as session:
            now = datetime.now(timezone.utc)
            print("now: {}".format(now))
            stmt = delete(StoryPost).where(StoryPost.expires_at <= now)
            await session.execute(stmt)
            await session.commit()
    except Exception as e:
        print(f"Error deleting expired story posts: {e}")
        await session.rollback()

@app.task
def delete_expired_story_posts_task():
    async_to_sync(_delete_expired_story_posts)()
