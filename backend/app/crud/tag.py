from typing import List
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.base import CRUDBase
from app.models import Tag, UserTag
from app.schemas.tag import TagBase


class TagCRUD(CRUDBase[Tag, TagBase]):
    def __init__(self):
        super().__init__(Tag, TagBase)

    async def get_tags_by_user_id(self, db: AsyncSession, user_id: int) -> List[TagBase]:
        result = await db.execute(
            select(Tag)
            .join(UserTag)
            .where(UserTag.user_id == user_id)
        )
        tags = result.scalars().all()
        return [TagBase.model_validate(tag) for tag in tags]


def get_tag_crud() -> TagCRUD:
    return TagCRUD()
