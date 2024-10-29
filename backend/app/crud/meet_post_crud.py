from typing import List, Optional

from sqlmodel.ext.asyncio.session import AsyncSession

from sqlalchemy import select
from sqlalchemy import and_
from app.crud.base import CRUDBase
from app.models import MeetPost
from app.schemas.meet_post_schemas import MeetPostBase, MeetPostCreate

class MeetPostQueryBuilder:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.query = select(MeetPost)
        self.filter_conditions = []

    def filter_by_title(self, title: str):
        """제목에 따라 필터링"""
        self.filter_conditions.append(MeetPost.title.ilike(f"%{title}%"))
        return self

    def filter_by_type(self, post_type: str):
        """타입에 따라 필터링"""
        self.filter_conditions.append(MeetPost.type == post_type)
        return self

    def filter_by_content(self, content: str):
        """내용에 따라 필터링"""
        self.filter_conditions.append(MeetPost.content.ilike(f"%{content}%"))
        return self

    def add_pagination(self, skip: int, limit: int):
        """페이지네이션 적용"""
        self.query = self.query.offset(skip).limit(limit)
        return self

    async def build(self):
        """쿼리 실행 및 결과 반환"""
        if self.filter_conditions:
            self.query = self.query.where(and_(*self.filter_conditions))

        result = await self.db.exec(self.query)
        return result.all()

class MeetPostCRUDProtocol:
    def create(self,db: AsyncSession,
    meet_post: MeetPostCreate) -> MeetPostBase:
        pass

    async def get(self, db: AsyncSession, meet_post_id: int) -> MeetPostBase:
        pass

    async def update(self, db: AsyncSession, meet_post: MeetPostBase) -> (
            MeetPostBase):
            pass

    async def delete(self, meet_post_id: int) -> bool:
        pass

    async def get_filtered_posts(
            self,
            db: AsyncSession,
            title: Optional[str] = None,
            post_type: Optional[str] = None,
            content: Optional[str] = None,
            skip: int = 0,
            limit: int = 10
    ) -> Optional[List[MeetPostBase]]:
        pass


class MeetPostCRUD(CRUDBase[MeetPost, MeetPostBase], MeetPostCRUDProtocol):
    def __init__(self):
        super().__init__(MeetPost, MeetPostBase)

    async def create(self, db: AsyncSession, meet_post: MeetPostCreate) -> (
    MeetPostBase):
        return await super().create(db, meet_post)

    async def get(self, db: AsyncSession, meet_post_id: int) -> MeetPostBase:
        return await super().get(db, meet_post_id)

    async def update(self, db: AsyncSession, meet_post: MeetPostBase) -> (
    MeetPostBase):
        return await super().update(db, meet_post)

    async def get_filtered_posts(
                self,
                db: AsyncSession,
                title: Optional[str] = None,
                post_type: Optional[str] = None,
                content: Optional[str] = None,
                skip: int = 0,
                limit: int = 10
        ) -> Optional[List[MeetPostBase]]:
        query_builder = MeetPostQueryBuilder(db)
        if title:
            query_builder.filter_by_title(title)
        if post_type:
            query_builder.filter_by_type(post_type)
        if content:
            query_builder.filter_by_content(content)

        query_builder.add_pagination(skip, limit)
        posts = await query_builder.build()
        return [MeetPostBase.model_validate(post) for post in posts]


def get_meet_post_crud() -> MeetPostCRUDProtocol:
    return MeetPostCRUD()