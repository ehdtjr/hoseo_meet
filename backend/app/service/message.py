import bisect
import json
from datetime import timezone
from typing import List, Optional, Protocol
from uuid import uuid4

from sqlalchemy import func, select, text

from fastapi import HTTPException, Depends
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.exceptions import PermissionDeniedException
from app.crud.message import MessageCRUDProtocol, UserMessageCRUDProtocol, \
    get_message_crud, get_user_message_crud
from app.crud.recipient import RecipientCRUDProtocol, get_recipient_crud
from app.crud.stream import SubscriptionCRUDProtocol, get_subscription_crud
from app.models.message import Message, MessageType
from app.models.message_outbox import MessageOutbox
from app.schemas.event import EventBase
from app.schemas.message import MessageBase, MessageCreate, UserMessageBase, \
    MessageResponse, MessageSendResponse
from app.service.event.events import EventDispatcher, get_event_dispatcher


class MessageSendServiceProtocol(Protocol):
    async def send_message_stream(
            self,
            db: AsyncSession,
            sender_id: int,
            stream_id: int,
            message_content: str,
            client_message_id: Optional[str] = None) -> MessageSendResponse:
        pass


class MessageSendService(MessageSendServiceProtocol):
    def __init__(
            self,
            message_crud: MessageCRUDProtocol,
            user_message_crud: UserMessageCRUDProtocol,
            recipient_crud: RecipientCRUDProtocol,
            subscription_crud: SubscriptionCRUDProtocol,
    ):
        self.message_crud = message_crud
        self.user_message_crud = user_message_crud
        self.recipient_crud = recipient_crud
        self.subscription_crud = subscription_crud

    async def send_message_stream(
        self, db: AsyncSession, sender_id: int, stream_id: int,
        message_content: str, client_message_id: Optional[str] = None,
    ) -> MessageSendResponse:
        # Authentication may already have started a read transaction on this
        # request-scoped session. The service owns its commit/rollback boundary.
        key = client_message_id if client_message_id is not None else str(uuid4())
        if not key or len(key) > 128 or not key.isascii() or any(c.isspace() for c in key):
            raise HTTPException(status_code=422, detail="Invalid client message ID")
        try:
            subscribers = await self.subscription_crud.get_subscribers(db, stream_id)
            if sender_id not in subscribers:
                raise PermissionDeniedException(
                    "You are not permitted to send messages to this stream")
            recipient = await self.recipient_crud.get_by_type_id(db, stream_id)

            # Serialize identical sender/key requests, including concurrent HTTP
            # retries. The unique index is a second database-level safeguard.
            await db.execute(text(
                "SELECT pg_advisory_xact_lock(hashtextextended(:key, 0))"
            ), {"key": f"message:{sender_id}:{key}"})
            existing = await db.scalar(select(Message).where(
                Message.sender_id == sender_id, Message.client_message_id == key))
            if existing is not None:
                if existing.recipient_id != recipient.id or existing.content != message_content:
                    raise HTTPException(status_code=409,
                                        detail="Client message ID already used for a different message")
                pending = await db.scalar(select(func.count()).select_from(MessageOutbox).where(
                    MessageOutbox.message_id == existing.id,
                    MessageOutbox.completed_at.is_(None)))
                response = MessageSendResponse(
                    message_id=existing.id, client_message_id=key, duplicate=True,
                    delivery_status="pending" if pending else "completed")
            else:
                message = await self.message_crud.send_message_create(db, MessageCreate(
                    sender_id=sender_id, type=MessageType.NORMAL,
                    recipient_id=recipient.id, content=message_content,
                    client_message_id=key))
                await self.user_message_crud.bulk_create(db, [
                    {"user_id": user_id, "message_id": message.id}
                    for user_id in subscribers
                ])
                message.date_sent = message.date_sent.astimezone(timezone.utc)
                payload = MessageResponse(
                    **message.model_dump(), stream_id=stream_id,
                    unread_count=len(subscribers)).model_dump_json()
                db.add_all([MessageOutbox(message_id=message.id, user_id=user_id,
                                          stream_id=stream_id, payload=payload)
                            for user_id in subscribers])
                response = MessageSendResponse(
                    message_id=message.id, client_message_id=key, delivery_status="pending")
            await db.commit()
            return response
        except BaseException:
            await db.rollback()
            raise


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
                client_message_id=msg.client_message_id,
                rendered_content=msg.rendered_content,
                date_sent=msg.date_sent,
                stream_id=stream_id,
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

        event = EventBase(
            type="read",
            data=json.dumps({"read_message": read_messages})
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
) -> MessageSendServiceProtocol:
    return MessageSendService(
        message_crud=message_crud,
        user_message_crud=user_message_crud,
        recipient_crud=recipient_crud,
        subscription_crud=subscription_crud,
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
