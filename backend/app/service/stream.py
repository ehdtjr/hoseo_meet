import logging
from typing import Dict, List

from psycopg import DatabaseError
from sqlalchemy.ext.asyncio import AsyncSession
from typing_extensions import Optional, Protocol

from app.crud.message import MessageCRUDProtocol, UserMessageCRUDProtocol, \
    get_message_crud, get_user_message_crud
from app.crud.recipient import RecipientCRUDProtocol, get_recipient_crud
from app.crud.stream import StreamCRUDProtocol, SubscriptionCRUDProtocol, \
    get_stream_crud, get_subscription_crud
from app.schemas.message import MessageBase, UserMessageBase
from app.schemas.recipient import RecipientCreate, RecipientType
from app.schemas.stream import StreamBase, StreamCreate, StreamRead, \
    SubscriptionCreate, \
    SubscriptionRead

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class StreamServiceProtocol(Protocol):
    async def create_stream(self, db: AsyncSession,
                            stream_create: StreamCreate) -> StreamRead:
        pass


class StreamService(StreamServiceProtocol):
    def __init__(self, stream_crud: StreamCRUDProtocol,
                 recipient_crud: RecipientCRUDProtocol):
        self.stream_crud = stream_crud
        self.recipient_crud = recipient_crud

    async def create_stream(self, db: AsyncSession,
                            stream_create: StreamCreate) -> Optional[
                            StreamRead]:
        try:
            created_stream: StreamBase = await self.stream_crud.create(db,
            obj_in=stream_create)

            if created_stream:
                recipient_data = RecipientCreate(type=RecipientType.STREAM,
                                                 type_id=created_stream.id)
                recipient = await self.recipient_crud.create(db,
                                                             obj_in=recipient_data)
                # update recipient
                created_stream.recipient_id = recipient.id
                update_stream = await self.stream_crud.update(db, created_stream)
                return StreamRead.model_validate(update_stream)
            else:
                logger.info("Error create stream")
                return None
        except DatabaseError as db_err:
            logger.error(f"Database error while creating stream: {db_err}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error while creating stream: {e}")
            return None

def get_stream_service() -> StreamServiceProtocol:
    return StreamService(get_stream_crud(), get_recipient_crud())


class SubscriberServiceProtocol(Protocol):
    async def subscribe(self, db: AsyncSession, user_id: int,
                        stream_id: int) \
            -> Optional[SubscriptionRead]:
        pass

    async def get_subscription_list(self, db: AsyncSession, user_id: int) \
            -> List[Dict]:
        pass

    async def get_subscribers(self, db: AsyncSession, stream_id: int) -> \
                List[int]:
                pass


class SubscriberService(SubscriberServiceProtocol):
    user_message_crud: UserMessageCRUDProtocol

    def __init__(self, subscription_crud: SubscriptionCRUDProtocol,
                 stream_crud: StreamCRUDProtocol,
                 recipient_crud: RecipientCRUDProtocol,
                 user_message_crud: UserMessageCRUDProtocol,
                 message_crud: MessageCRUDProtocol

                 ):
        self.subscription_crud = subscription_crud
        self.stream_crud = stream_crud
        self.recipient_crud = recipient_crud
        self.user_message_crud = user_message_crud
        self.message_curd = message_crud

    async def get_subscription_list(self, db: AsyncSession, user_id: int) -> \
            List[Dict]:
        result = await self.subscription_crud.get_subscription_list(db, user_id)
        subscriptions = []

        for stream, subscription in result:
            # 구독자 목록 가져오기
            subscribers = await self.get_subscribers(
                db, stream.id)

            # 미읽음 메시지 수 가져오기
            unread_message_count = await (
                self.user_message_crud.get_first_unread_message_in_stream_count(
                    db, user_id, stream.id))

            # 가장 최근의 유저 메시지 가져오기
            user_last_message: Optional[UserMessageBase] = await (
                self.user_message_crud.get_newest_message_in_stream(db, user_id,
                                                                    stream.id))

            last_message = None
            if user_last_message:
                last_message: MessageBase = await self.message_curd.get(
                    db, user_last_message.message_id
                )

            # 구독 정보에 스트림, 마지막 메시지, 미읽음 메시지 수 추가
            subscriptions.append({
                "stream_id": stream.id,
                "creator_id": stream.creator_id,
                "name": stream.name,
                "type": stream.type,
                "is_muted": subscription.is_muted,
                "subscribers": subscribers,
                "last_message": last_message if last_message else "No "
                                                                  "messages",
                "unread_message_count": unread_message_count
            })
        return subscriptions

    async def get_subscribers(self, db: AsyncSession, stream_id: int) -> \
            List[int]:
        return  await self.subscription_crud.get_subscribers(
        db, stream_id)

    async def subscribe(self, db: AsyncSession, user_id: int,
                        stream_id: int) \
            -> Optional[SubscriptionRead]:
        recipient = await self.recipient_crud.get_by_type_id(db, stream_id)
        subscribers: List[int] = await self.subscription_crud.get_subscribers(
            db, stream_id)

        if user_id in subscribers:
            raise ValueError(f"User {user_id} is already subscribed")

        subscriber_data = SubscriptionCreate(
            user_id=user_id,
            recipient_id=recipient.id,
        )
        subscriber = await self.subscription_crud.create(db, subscriber_data)

        return SubscriptionRead.model_validate(subscriber)



def get_subscription_service() -> SubscriberServiceProtocol:
    return SubscriberService(
        subscription_crud=get_subscription_crud(),
        stream_crud=get_stream_crud(),
        recipient_crud=get_recipient_crud(),
        user_message_crud=get_user_message_crud(),
        message_crud=get_message_crud()
    )
