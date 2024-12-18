from typing import Optional, List

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.base import CRUDBase  # CRUDBase 가져오기
from app.models.user import User, UserFCMToken  # User 모델 가져오기
from app.schemas.user import UserFCMTokenBase, UserFCMTokenCreate, \
    UserRead, \
    UserUpdate


class UserCRUDProtocol:
    async def get(self, db: AsyncSession, id: int) -> UserRead:
        pass

    async def update(self, db: AsyncSession, user_in: UserUpdate) -> UserRead:
        pass

    async def get_users_by_ids(self, db: AsyncSession, user_ids: List[int])\
     -> List[UserRead]:
        pass


class UserCRUD(CRUDBase[User, UserRead], UserCRUDProtocol):
    def __init__(self):
        super().__init__(User, UserRead)

    async def get(self, db: AsyncSession, id: int) -> Optional[UserRead]:
        return await super().get(db, id)

    async def update(self, db: AsyncSession,
                     user_in: UserUpdate) -> UserRead:
        return await super().update(db, user_in)

    async def get_users_by_ids(self, db: AsyncSession, user_ids: List[int])\
     -> List[UserRead]:
        if not user_ids:
            return []
        result = await db.execute(
            select(User).where(User.id.in_(user_ids))
        )
        users = result.scalars().all()
        return [UserRead.model_construct(**u.__dict__) for u in users]

class UserFCMTokenCRUDProtocol:
    async def get(self, db: AsyncSession, id: int) -> UserFCMTokenCreate:
        pass

    async def get_user_fcm_token_by_user_id(self, db: AsyncSession,
                                            user_id: int) -> Optional[
        UserFCMTokenBase]:
        pass

    async def create(self, db: AsyncSession, obj_in: UserFCMTokenCreate) -> (
            UserFCMTokenBase):
        pass

    async def update(self, db: AsyncSession,
                     user_in: UserFCMTokenBase) -> UserFCMTokenCreate:
        pass


class UserFCMTokenCRUD(CRUDBase[UserFCMToken, UserFCMTokenBase],
                       UserFCMTokenCRUDProtocol):
    def __init__(self):
        super().__init__(UserFCMToken, UserFCMTokenBase)

    async def get_user_fcm_token_by_user_id(self, db: AsyncSession, user_id:
    int) -> Optional[UserFCMTokenBase]:
        # 유저 ID로 FCM 토큰을 찾는 쿼리
        query = select(UserFCMToken).where(UserFCMToken.user_id== user_id)

        # 쿼리 실행
        result = await db.execute(query)

        # 결과 추출
        user_fcm_token = result.scalars().first()

        if user_fcm_token is None:
            return None

        return UserFCMTokenBase.model_validate(user_fcm_token)

    async def create(self, db: AsyncSession, obj_in: UserFCMTokenCreate) -> (
            Optional)[
        UserFCMTokenBase]:
        return await super().create(db, obj_in)

    async def update(self, db: AsyncSession,
                     obj_in: UserFCMTokenBase) -> UserFCMTokenBase:
        return await super().update(db, obj_in)


def get_user_crud() -> UserCRUDProtocol:
    return UserCRUD()


def get_user_fcm_token_crud() -> UserFCMTokenCRUDProtocol:
    return UserFCMTokenCRUD()
