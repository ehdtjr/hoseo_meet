import bisect
from typing import List, Optional, Protocol

from fastapi import HTTPException, Depends
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.exceptions import PermissionDeniedException
from app.crud.message import MessageCRUDProtocol, UserMessageCRUDProtocol, \
    get_message_crud, get_user_message_crud
from app.crud.recipient import RecipientCRUDProtocol, get_recipient_crud
from app.crud.stream import SubscriptionCRUDProtocol, get_subscription_crud
from app.models.message import MessageType
from app.schemas.event import EventBase
from app.schemas.message import MessageBase, MessageCreate, UserMessageBase, \
    MessageResponse
from app.service.event.events import EventDispatcher, get_event_dispatcher


class MessageSendServiceProtocol(Protocol):
    async def send_message_stream(
            self,
            db: AsyncSession,
            sender_id: int,
            stream_id: int,
            message_content: str) -> None:
        pass


class MessageSendService(MessageSendServiceProtocol):
    def __init__(
            self,
            message_crud: MessageCRUDProtocol,
            user_message_crud: UserMessageCRUDProtocol,
            recipient_crud: RecipientCRUDProtocol,
            subscription_crud: SubscriptionCRUDProtocol,
            event_dispatcher: EventDispatcher
    ):
        self.message_crud = message_crud
        self.user_message_crud = user_message_crud
        self.recipient_crud = recipient_crud
        self.subscription_crud = subscription_crud
        self.event_dispatcher = event_dispatcher

    async def send_message_stream(self, db: AsyncSession, sender_id: int,
                                  stream_id: int, message_content: str) -> None:

        subscribers = await self.subscription_crud.get_subscribers(db,
                                                                   stream_id)
        if sender_id not in subscribers:
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
        message = await self.message_crud.send_message_create(db,
                                                              message_create)

        # UserMessage 대량 생성
        user_messages_data = [{"user_id": subscriber, "message_id": message.id}
                              for subscriber in subscribers]
        await self.user_message_crud.bulk_create(db, user_messages_data)

        # EventBase 생성
        event_data: EventBase = EventBase(
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

        # EventDispatcher로 이벤트 전송
        await self.event_dispatcher.dispatch(db,
                                             user_ids=subscribers,
                                             stream_id=stream_id,
                                             event_data=event_data)


class MessageServiceProtocol(Protocol):
    async def mark_message_read_stream(self, db: AsyncSession, stream_id: int,
                                       user_id: int, anchor: str,
                                       num_before: int,
                                       num_after: int) -> List[int]:
        pass

    async def get_stream_messages(self, db: AsyncSession,
                                  user_id: int,
                                  stream_id: int,
                                  anchor: str,
                                  num_before: int,
                                  num_after: int) -> (
            Optional)[List[MessageResponse]]:
        pass


class MessageService(MessageServiceProtocol):
    def __init__(self, message_crud: MessageCRUDProtocol,
                 user_message_crud: UserMessageCRUDProtocol,
                 subscription_crud: SubscriptionCRUDProtocol,
                 event_dispatcher: EventDispatcher
                 ):
        self.message_crud = message_crud
        self.user_message_crud = user_message_crud
        self.subscription_crud = subscription_crud
        self.event_dispatcher = event_dispatcher

    async def get_stream_messages(self, db: AsyncSession,
                                  user_id: int,
                                  stream_id: int,
                                  anchor: str,
                                  num_before: int,
                                  num_after: int) -> List[MessageResponse]:

        if not await self._check_stream_permission(db, user_id, stream_id):
            raise PermissionDeniedException(
                "You are not permitted to read messages from this stream")

        anchor_id: int = await self._convert_anchor_to_id(db, anchor, user_id,
                                                          stream_id)
        messages: List[
            MessageBase] = await self.message_crud.get_stream_messages(
            db, stream_id, anchor_id, num_before, num_after)

        user_oldest_message: Optional[UserMessageBase] = await (
            self.user_message_crud.get_oldest_message_in_stream(db,
                                                                user_id,
                                                                stream_id))

        if messages and user_oldest_message:
            start_idx = bisect.bisect_left([msg.id for msg in messages],
                                           user_oldest_message.message_id)
            messages = messages[start_idx:]

        message_ids = [msg.id for msg in messages]

        unread_map: dict[int, int] = await (
        self.user_message_crud.get_unread_counts_for_messages(db,
        message_ids=message_ids))

        response_list: List[MessageResponse] = []
        for msg in messages:
            unread_count = unread_map.get(msg.id, 0)
            message_response = MessageResponse(
                id=msg.id,
                sender_id=msg.sender_id,
                type=msg.type,
                recipient_id=msg.recipient_id,
                content=msg.content,
                rendered_content=msg.rendered_content,
                date_sent=msg.date_sent,
                unread_count=unread_count
            )
            response_list.append(message_response)

        return response_list

    async def mark_message_read_stream(self, db: AsyncSession, stream_id: int,
                                       user_id: int,
                                       anchor: str,
                                       num_before: int,
                                       num_after: int) -> List[int]:
        if not await self._check_stream_permission(db, user_id, stream_id):
            raise HTTPException(status_code=403, detail="Forbidden")

        anchor_id: int = await self._convert_anchor_to_id(db, anchor, user_id,
                                                          stream_id)
        read_messages: List[int] = await (
            self.user_message_crud.mark_stream_messages_read(
                db,
                user_id,
                stream_id,
                anchor_id,
                num_before,
                num_after
        ))

        event: EventBase = EventBase(
            type="read",
            data={
               "read_message": read_messages
            }
        )

        subscribers = await self.subscription_crud.get_subscribers(db,
                                                                   stream_id)

        await self.event_dispatcher.dispatch(db,
                                             user_ids=subscribers,
                                             stream_id=stream_id,
                                             event_data=event)

        return read_messages

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
                                        detail="No messages found in the "
                                               "stream")
            return result.message_id
        else:
            return int(anchor)


def get_message_send_service(
        message_crud: MessageCRUDProtocol = Depends(get_message_crud),
        user_message_crud: UserMessageCRUDProtocol = Depends(
            get_user_message_crud),
        recipient_crud: RecipientCRUDProtocol = Depends(
            get_recipient_crud),
        subscription_crud: SubscriptionCRUDProtocol = Depends(
            get_subscription_crud),
        event_dispatcher: EventDispatcher = Depends(get_event_dispatcher)
) -> MessageSendServiceProtocol:
    return MessageSendService(
        message_crud=message_crud,
        user_message_crud=user_message_crud,
        recipient_crud=recipient_crud,
        subscription_crud=subscription_crud,
        event_dispatcher=event_dispatcher
    )


def get_message_service(
    message_crud: MessageCRUDProtocol = Depends(get_message_crud),
    user_message_crud: UserMessageCRUDProtocol = Depends(
        get_user_message_crud),
    subscription_crud: SubscriptionCRUDProtocol = Depends(
        get_subscription_crud),
    event_dispatcher: EventDispatcher = Depends(get_event_dispatcher)
) -> MessageServiceProtocol:
    return MessageService(
        message_crud=message_crud,
        user_message_crud=user_message_crud,
        subscription_crud=subscription_crud,
        event_dispatcher=event_dispatcher
    )
