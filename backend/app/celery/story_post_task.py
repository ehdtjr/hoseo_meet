import logging
from datetime import datetime, timezone

from pydantic_core import MultiHostUrl
from sqlalchemy import create_engine, delete
from sqlalchemy.orm import sessionmaker
from app.core.config import settings
from app.models import StoryPost
from app.celery.worker import app


def SQLALCHEMY_DATABASE_URI() -> MultiHostUrl:
    return MultiHostUrl.build(
        scheme="postgresql",
        username=settings.POSTGRES_USER,
        password=settings.POSTGRES_PASSWORD,
        host=settings.POSTGRES_SERVER,
        port=settings.POSTGRES_PORT,
        path=settings.POSTGRES_DB,
    )


sync_engine = create_engine(
    str(SQLALCHEMY_DATABASE_URI()),
    pool_size=20,
    max_overflow=10,
)

# 동기 세션 메이커 생성
sync_session_maker = sessionmaker(
    sync_engine,
    expire_on_commit=False,
)

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
