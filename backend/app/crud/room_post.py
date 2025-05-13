from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.base import CRUDBase
from app.models.room_post import RoomPostHeart
from app.schemas.room_post import RoomPostHeartBase


class RoomPostHeartCRUDProtocol:
    async def create(
        self, db: AsyncSession, obj_in: RoomPostHeartBase
    ) -> RoomPostHeartBase:
        ...

    async def get_by_user_and_room(
        self,
        db: AsyncSession,
        user_id: int,
        room_id: int,
    ) -> Optional[RoomPostHeartBase]:
        ...

    async def delete(
        self,
        db: AsyncSession,
        room_post_heart: int
    ) -> None:
        ...

    async def is_heart(
        self, db: AsyncSession, user_id: int, room_id: int
    ) -> bool:
        ...


class RoomPostHeartCRUD(
    CRUDBase[RoomPostHeart, RoomPostHeartBase],
    RoomPostHeartCRUDProtocol
):
    def __init__(self):
        super().__init__(RoomPostHeart, RoomPostHeartBase)

    async def create(
        self, db: AsyncSession, obj_in: RoomPostHeartBase
    ) -> RoomPostHeartBase:
        return await super().create(db, obj_in)

    async def get_by_user_and_room(
            self,
            db: AsyncSession,
            user_id: int,
            room_id: int,
    ) -> Optional[RoomPostHeartBase]:
        stmt = select(RoomPostHeart).where(
            RoomPostHeart.user_id == user_id,
            RoomPostHeart.room_id == room_id
        )

        result = await db.execute(stmt)
        db_obj = result.scalar_one_or_none()

        if db_obj is not None:
            return RoomPostHeartBase.model_validate(
                db_obj)
        return None

    async def delete(
        self,
        db: AsyncSession,
        room_post_heart_id: int,
    ):
        return await super().delete(db, room_post_heart_id)

    async def is_heart(
        self, db: AsyncSession, user_id: int, room_id: int
    ) -> bool:
        stmt = select(RoomPostHeart).where(
            RoomPostHeart.user_id == user_id,
            RoomPostHeart.room_id == room_id,
        )
        result = await db.execute(stmt)
        return result.scalar() is not None


async def get_room_post_heart() -> RoomPostHeartCRUDProtocol:
    return RoomPostHeartCRUD()
