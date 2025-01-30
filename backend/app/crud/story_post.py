from sqlalchemy import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.crud.base import CRUDBase
from app.models import StoryPost
from app.schemas.story_post import StoryPostBase, StoryPostCreate


class StoryPostCRUD(CRUDBase[StoryPost, StoryPostBase]):
    def __init__(self):
            super().__init__(StoryPost, StoryPostBase)

    async def create(self, db: AsyncSession, story_post: StoryPostCreate) -> (
        StoryPostBase):
        return await super().create(db, story_post)

    async def get(self, db: AsyncSession, story_post_id: int) -> StoryPostBase:
        return await super().get(db, story_post_id)

    async def update(self, db: AsyncSession, story_post: StoryPostBase) -> (
                StoryPostBase):
            return await super().update(db, story_post)

    async def delete(self, db: AsyncSession, story_post_id: int) -> None:
        return await super().delete(db, story_post_id)

    async def list(self, db: AsyncSession, skip: int = 0, limit: int = 10) -> \
    list[StoryPostBase]:
        query = (
            select(StoryPost).order_by(StoryPost.id.desc()).offset(skip).limit(
                limit)
        )
        result = await db.execute(query)
        posts = result.scalars().all()
        return [
            StoryPostBase.model_construct(
                id=post.id,
                author_id=post.author_id,
                stream_id=post.stream_id,
                text_overlay=post.text_overlay,
                image_url=post.image_url,
                created_at=post.created_at,
                expires_at=post.expires_at,
            )
            for post in posts
        ]


async def get_story_post_crud() -> StoryPostCRUD:
    return StoryPostCRUD()