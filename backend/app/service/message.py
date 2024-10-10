import asyncio
from typing import List, Protocol

from aioredis import Redis
from fastapi import HTTPException
from sqlmodel.ext.asyncio.session import AsyncSession

from app.crud.message import MessageCRUDProtocol, UserMessageCRUDProtocol, \
    get_message_crud, get_user_message_crud
from app.crud.recipient import RecipientCRUDProtocol, get_recipient_crud
from app.crud.stream import SubscriptionCRUDProtocol, get_subscription_crud
from app.models.message import MessageType
from app.schemas.message import MessageBase, MessageCreate, UserMessageBase
from app.service.events import send_event


class MessageServiceProtocol(Protocol):
    async def send_message_stream(self, db: AsyncSession, redis: Redis,
                                  sender_id: int, stream_id: int,
                                  message_content: str) -> None:
        pass

    async def mark_message_read_stream(self, db: AsyncSession, stream_id: int,
                                       user_id: int, anchor: str,
                                       num_before: int,
                                       num_after: int) -> None:
        pass

    async def get_stream_messages(self, db: AsyncSession,
                                  user_id: int,
                                  stream_id: int,
                                  anchor: str,
                                  num_before: int,
                                  num_after: int) -> List[MessageBase]:
        pass


class MessageService(MessageServiceProtocol):
    def __init__(self, message_crud: MessageCRUDProtocol,
                 user_message_crud: UserMessageCRUDProtocol,
                 recipient_crud: RecipientCRUDProtocol,
                 subscription_crud: SubscriptionCRUDProtocol):
        self.message_crud = message_crud
        self.user_message_crud = user_message_crud
        self.recipient_crud = recipient_crud
        self.subscription_crud = subscription_crud

    async def send_message_stream(self, db: AsyncSession, redis: Redis,
                                  sender_id: int, stream_id: int,
                                  message_content: str) -> None:
        recipient = await self.recipient_crud.get_by_type_id(db, stream_id)

        message_create = await self._create_message_data(sender_id,
                                                         recipient.id,
                                                         message_content)
        message = await self.message_crud.create(db, message_create)

        subscribers = await self.subscription_crud.get_subscribers(db,
                                                                   stream_id)

        user_messages_data = [{"user_id": subscriber, "message_id": message.id}
                              for subscriber in subscribers]
        await self.user_message_crud.bulk_create(db, user_messages_data)

        event_data = await self._create_event_data(message, stream_id)

        await asyncio.gather(
            *[send_event(redis, subscriber, event_data) for subscriber in
              subscribers]
        )

    async def _create_message_data(self, sender_id: int, recipient_id: int,
                                   message_content: str) -> MessageCreate:
        """MessageCreate 데이터를 생성하는 헬퍼 메서드"""
        message_create_data = {
            "sender_id": sender_id,
            "type": MessageType.NORMAL,
            "recipient_id": recipient_id,
            "content": message_content
        }
        return MessageCreate.model_validate(message_create_data)

    async def _create_event_data(self, message: MessageBase,
                                 stream_id: int) -> dict:
        """Redis로 보낼 이벤트 데이터를 생성하는 헬퍼 메서드"""
        return {
            "type": "stream",
            "data": {
                "id": message.id,
                "stream_id": stream_id,
                "sender_id": message.sender_id,
                "recipient_id": message.recipient_id,
                "content": message.content,
                "date_sent": int(message.date_sent.timestamp()),
                "is_read": False
            }
        }

    async def get_stream_messages(self, db: AsyncSession,
                                  user_id: int,
                                  stream_id: int,
                                  anchor: str,
                                  num_before: int,
                                  num_after: int) -> List[MessageBase]:
        if not await self._check_stream_permission(db, user_id, stream_id):
            raise HTTPException(status_code=403, detail="Forbidden")

        anchor_id: int = await self._convert_anchor_to_id(db, anchor, user_id,
                                                          stream_id)

        messages: List[
            MessageBase] = await self.message_crud.get_stream_messages(
            db, stream_id, anchor_id, num_before, num_after)
        return messages

    async def mark_message_read_stream(self, db: AsyncSession, stream_id: int,
                                       user_id: int, anchor: str,
                                       num_before: int,
                                       num_after: int) -> None:
        if not await self._check_stream_permission(db, user_id, stream_id):
            raise HTTPException(status_code=403, detail="Forbidden")

        anchor_id: int = await self._convert_anchor_to_id(db, anchor, user_id,
                                                          stream_id)
        await self.user_message_crud.mark_stream_messages_read(
            db,
            user_id,
            stream_id,
            anchor_id,
            num_before,
            num_after
        )

    async def _check_stream_permission(self,
                                       db: AsyncSession,
                                       user_id: int,
                                       stream_id: int) -> bool:
        subscribers = await self.subscription_crud.get_subscribers(db,
                                                                   stream_id)
        if user_id not in subscribers:
            return False
        return True

    async def _convert_anchor_to_id(self, db: AsyncSession,
                                    anchor: str,
                                    user_id: int,
                                    stream_id) -> int:
        if anchor == "newest":
            result: UserMessageBase = (
                await self.user_message_crud.get_newest_message_in_stream(
                    db,
                    user_id,
                    stream_id))
            return result.message_id
        elif anchor == "oldest":
            result: UserMessageBase = (
                await self.user_message_crud.get_oldest_message_in_stream(
                    db,
                    user_id,
                    stream_id))
            return result.message_id
        elif anchor == "first_unread":
            result: UserMessageBase = (
                await self.user_message_crud.get_first_unread_message_in_stream(
                    db,
                    user_id,
                    stream_id))

            if result is None:
                result = await (
                    self.user_message_crud.get_oldest_message_in_stream(
                        db,
                        user_id,
                        stream_id))

            if result is None:
                raise HTTPException(status_code=404,
                                    detail="No messages found in the stream")

            return result.message_id

        else:
            return int(anchor)


def get_message_service() -> MessageServiceProtocol:
    return MessageService(get_message_crud(),
                          get_user_message_crud(),
                          get_recipient_crud(),
                          get_subscription_crud())
