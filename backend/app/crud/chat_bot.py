from typing import List

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.base import CRUDBase
from app.models import ChatBotMessage
from app.schemas.chat_bot import ChatBotMessageBase


# Two-key advisory locks have a separate key space from the one-key locks used
# elsewhere. Acquire before INSERT so sequence IDs follow per-user commit order.
CHAT_MESSAGE_WRITE_LOCK = 290030


class ChatBotMessageCRUD(CRUDBase[ChatBotMessage, ChatBotMessageBase]):
    def __init__(self):
        super().__init__(ChatBotMessage, ChatBotMessageBase)

    async def create(self, db: AsyncSession, chat_bot_message: ChatBotMessageBase) \
        -> ChatBotMessageBase:
        with db.no_autoflush:
            await db.execute(select(func.pg_advisory_xact_lock(
                CHAT_MESSAGE_WRITE_LOCK, chat_bot_message.user_id
            )))
        return await super().create(db, chat_bot_message)

    async def get_all_message(self, db: AsyncSession, user_id: int)\
         -> List[ChatBotMessageBase]:
        result = await db.execute(
            select(self.model).where(self.model.user_id == user_id)
        )
        rows = result.scalars().all()
        return [
            self.schema.model_validate(row.__dict__)
            for row in rows
        ]

async def get_chat_bot_message_crud():
    return ChatBotMessageCRUD()
