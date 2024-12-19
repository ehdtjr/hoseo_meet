import bisect
from typing import List, Optional, Protocol

from fastapi import HTTPException
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.exceptions import PermissionDeniedException
from app.crud.message import MessageCRUDProtocol, UserMessageCRUDProtocol, \
    get_message_crud, get_user_message_crud
from app.crud.recipient import RecipientCRUDProtocol, get_recipient_crud
from app.crud.stream import SubscriptionCRUDProtocol, get_subscription_crud
from app.crud.user_crud import UserCRUDProtocol, get_user_crud
from app.models.message import MessageType
from app.schemas.event import EventBase
from app.schemas.message import MessageBase, MessageCreate, UserMessageBase
from app.service.events import create_event_dispatcher, SenderSelectionContext


class MessageServiceProtocol(Protocol):
    async def send_message_stream(self,
    db: AsyncSession,
    sender_id: int,stream_id: int,
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
                                  num_after: int) -> Optional[List[
                                  MessageBase]]:
        pass



class MessageService(MessageServiceProtocol):
    def __init__(self, message_crud: MessageCRUDProtocol,
                 user_message_crud: UserMessageCRUDProtocol,
                 user_crud: UserCRUDProtocol,
                 recipient_crud: RecipientCRUDProtocol,
                 subscription_crud: SubscriptionCRUDProtocol):
        self.message_crud = message_crud
        self.user_message_crud = user_message_crud
        self.user_crud = user_crud
        self.recipient_crud = recipient_crud
        self.subscription_crud = subscription_crud

    async def send_message_stream(self, db: AsyncSession, sender_id: int,
                                  stream_id: int, message_content: str) -> None:

        # 권한 체크
        if not await self._check_stream_permission(db, sender_id, stream_id):
            raise PermissionDeniedException(
                "You are not permitted to send messages to this stream")

        # Recipient 조회
        recipient = await self.recipient_crud.get_by_type_id(db, stream_id)

        # MessageCreate 직접 생성
        message_create_data = {
            "sender_id": sender_id,
            "type": MessageType.NORMAL,
            "recipient_id": recipient.id,
            "content": message_content
        }
        message_create = MessageCreate.model_validate(message_create_data)
        message = await self.message_crud.create(db, message_create)

        # 구독자 조회
        subscribers = await self.subscription_crud.get_subscribers(db,
                                                                   stream_id)
        # UserMessage 대량 생성
        user_messages_data = [{"user_id": subscriber, "message_id": message.id}
                              for subscriber in subscribers]
        await self.user_message_crud.bulk_create(db, user_messages_data)

        # EventBase 인스턴스 생성
        event_data = EventBase(
            type="stream",
            data={
                "id": message.id,
                "stream_id": stream_id,
                "sender_id": message.sender_id,
                "recipient_id": message.recipient_id,
                "content": message.content,
                "date_sent": int(message.date_sent.timestamp()),
                "is_read": False
            }
        )
        for sub_id in subscribers:
            context = SenderSelectionContext(user_id=sub_id,
                                             stream_id=stream_id)
            dispatcher = await create_event_dispatcher(db, context)
            await dispatcher.send_event(event_data)


    async def get_stream_messages(self, db: AsyncSession,
                                  user_id: int,
                                  stream_id: int,
                                  anchor: str,
                                  num_before: int,
                                  num_after: int) -> List[MessageBase]:

        if not await self._check_stream_permission(db, user_id, stream_id):
            raise PermissionDeniedException(
                "You are not permitted to read messages from this stream")

        anchor_id: int = await self._convert_anchor_to_id(db, anchor, user_id,
                                                          stream_id)
        messages: List[
            MessageBase] = await self.message_crud.get_stream_messages(
            db, stream_id, anchor_id, num_before, num_after)

        user_oldest_message: Optional[UserMessageBase] = await (
        self.user_message_crud.get_oldest_message_in_stream(
            db, user_id, stream_id))

        if messages and user_oldest_message:
            start_idx = bisect.bisect_left([msg.id for msg in messages],
             user_oldest_message.message_id)
            messages = messages[start_idx:]

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
            if result is None:
                raise HTTPException(status_code=404,
                                    detail="No messages found in the stream")
            return result.message_id
        elif anchor == "oldest":
            result: UserMessageBase = (
                await self.user_message_crud.get_oldest_message_in_stream(
                    db,
                    user_id,
                    stream_id))
            if result is None:
                raise HTTPException(status_code=404,
                                    detail="No messages found in the stream")
            return result.message_id
        elif anchor == "first_unread":
            result: UserMessageBase = (
                await self.user_message_crud.get_first_unread_message_in_stream(
                    db,
                    user_id,
                    stream_id))
            if result is None:
                result = await (
                    self.user_message_crud.get_newest_message_in_stream(
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
                          get_user_crud(),
                          get_recipient_crud(),
                          get_subscription_crud())
