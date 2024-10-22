from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.crud.base import CRUDBase
from app.models.recipient import Recipient
from app.schemas.recipient import RecipientBase, RecipientCreate  # type: ignore


class RecipientCRUDProtocol:
    async def create(self, db: AsyncSession, obj_in: RecipientCreate) \
            -> RecipientBase:
        pass

    async def get(self, db: AsyncSession, recipient_id: int) -> RecipientBase:
        pass

    async def delete(self, db: AsyncSession, recipient_id: int) -> Recipient:
        pass

    async def get_by_type_id(self, db: AsyncSession, type_id: int) -> Optional[
        RecipientBase]:
        pass


class RecipientCRUD(CRUDBase[Recipient, RecipientBase], RecipientCRUDProtocol):
    def __init__(self):
        super().__init__(Recipient, RecipientBase)

    async def create(self, db: AsyncSession, obj_in: RecipientCreate) \
            -> RecipientBase:
        return await super().create(db, obj_in)

    async def get(self, db: AsyncSession, recipient_id: int) -> RecipientBase:
        return await super().get(db, recipient_id)

    async def delete(self, db: AsyncSession, recipient_id: int) -> None:
        return await super().delete(db, recipient_id)

    async def get_by_type_id(self, db: AsyncSession, type_id: int) -> Optional[
        RecipientBase]:
        result = await db.execute(select(Recipient).where(
            Recipient.type_id == type_id))
        recipient = result.scalars().first()
        if recipient:
            return RecipientBase.model_validate(recipient)
        return None


def get_recipient_crud() -> RecipientCRUDProtocol:
    return RecipientCRUD()
