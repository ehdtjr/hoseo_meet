from sqlmodel.ext.asyncio.session import AsyncSession

from app.crud.base import CRUDBase
from app.models import MeetPost
from app.schemas.meet_post_schemas import MeetPostBase, MeetPostCreate


class MeetPostCRUDProtocol:
    def create(self,db: AsyncSession,
    meet_post: MeetPostCreate) -> MeetPostBase:
        pass

    def read(self, meet_post_id: int) -> MeetPostBase:
        pass

    def update(self, meet_post: MeetPostBase) -> MeetPostBase:
        pass

    def delete(self, meet_post_id: int) -> bool:
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

def get_meet_post_crud() -> MeetPostCRUDProtocol:
    return MeetPostCRUD()