from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.base import CRUDBase  # CRUDBase 가져오기
from app.models.user import User  # User 모델 가져오기
from app.schemas.user import UserRead, \
    UserUpdate


class UserCRUDProtocol:
    async def update(self, db: AsyncSession, user_in: UserUpdate) -> UserRead:
        pass


class UserCRUD(CRUDBase[User, UserRead], UserCRUDProtocol):
    def __init__(self):
        super().__init__(User, UserRead)

    async def update(self, db: AsyncSession,
                     user_in: UserUpdate) -> UserRead:
        return await super().update(db, user_in)


def get_user_crud() -> UserCRUDProtocol:
    return UserCRUD()
