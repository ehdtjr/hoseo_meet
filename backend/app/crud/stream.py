from typing import List, Optional, Sequence

from sqlalchemy import func
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.base import CRUDBase
from app.models import Recipient
from app.models.stream import Stream
from app.models.stream import Subscription
from app.schemas.recipient import RecipientType
from app.schemas.stream import StreamBase, StreamCreate, SubscriptionBase, \
    SubscriptionCreate


class StreamCRUDProtocol:
    async def create(self, db: AsyncSession,
                     obj_in: StreamCreate) -> StreamBase:
        pass

    async def get(self, db: AsyncSession, stream_id: int) -> Optional[Stream]:
        pass

    async def update(self, db: AsyncSession, obj_in: StreamBase) -> (
            StreamBase):
        pass

    async def delete(self, db: AsyncSession, stream_id: int) -> Stream:
        pass


class StreamCRUD(CRUDBase[Stream, StreamBase], StreamCRUDProtocol):
    def __init__(self):
        super().__init__(Stream, StreamBase)

    async def create(self, db: AsyncSession, obj_in: StreamCreate) -> (
            StreamBase):
        return await super().create(db, obj_in)

    async def get(self, db: AsyncSession, stream_id: int) -> Optional[Stream]:
        return await super().get(db, stream_id)

    async def update(self, db: AsyncSession, obj_in: StreamBase) -> StreamBase:
        return await super().update(db, obj_in)

    async def delete(self, db: AsyncSession, stream_id: int) -> None:
        await super().delete(db, stream_id)


def get_stream_crud() -> StreamCRUDProtocol:
    return StreamCRUD()


class SubscriptionCRUDProtocol:
    async def create(self, db: AsyncSession, obj_in: SubscriptionCreate) -> \
            SubscriptionBase:
        pass

    async def get(self, db: AsyncSession, subscription_id: int) -> (
            Optional)[Subscription]:
        pass

    async def update(self, db: AsyncSession, obj_in: SubscriptionBase) -> (
            SubscriptionBase):
        pass

    async def delete(self, db: AsyncSession,
                     subscription_id: int) -> Subscription:
        pass

    async def get_subscribers(self, db: AsyncSession, stream_id: int) -> (
            List)[int]:
        pass

    async def get_total_subscribed_user(self, db: AsyncSession, user_id: int) \
            -> int:
        pass

    async def get_subscribers_by_recipient(self, db: AsyncSession,
                                           recipient_id: int) -> List[
        SubscriptionBase]:
        pass

    async def get_subscription_list(self, db: AsyncSession, user_id: int) \
            -> List[tuple[StreamBase, SubscriptionBase]]:
        pass


class SubscriptionCRUD(CRUDBase[Subscription, SubscriptionBase],
                       SubscriptionCRUDProtocol):
    def __init__(self):
        super().__init__(Subscription, SubscriptionBase)

    async def create(self, db: AsyncSession, obj_in: SubscriptionCreate) -> (
            SubscriptionBase):
        return await super().create(db, obj_in)

    async def get(self, db: AsyncSession, subscription_id: int) -> Optional[
        Subscription]:
        return await super().get(db, subscription_id)

    async def update(self, db: AsyncSession,
                     obj_in: SubscriptionBase) -> SubscriptionBase:
        return await super().update(db, obj_in)

    async def delete(self, db: AsyncSession, subscription_id: int) -> None:
        await super().delete(db, subscription_id)

    async def get_all_by_user(self, db: AsyncSession, user_id: int) -> \
            List[SubscriptionBase]:
        query = select(self.model).where(self.model.user_id == user_id)
        result = await db.execute(query)
        subscriptions = result.scalars().all()
        return [self.schema.model_validate(sub.__dict__) for sub in
                subscriptions]

    async def get_by_recipient_type(
            self,
            db: AsyncSession,
            recipient_type: RecipientType,
            user_id: int
    ) -> list[SubscriptionBase]:
        query = (
            select(self.model)
            .join(Recipient, Recipient.id == Subscription.recipient)
            .where(Subscription.user == user_id,
                   Recipient.type == recipient_type.value)
        )

        result = await db.execute(query)
        subscriptions = result.scalars().all()

        # 데이터 검증 및 변환
        return [SubscriptionBase.model_validate(sub) for sub in subscriptions]

    async def get_subscribers(
            self, db: AsyncSession, stream_id: int) -> Sequence[int]:
        """
            stream 에 구독한 유저 id를  반환 하는 함수
        """
        result = await db.execute(
            select(Subscription.user_id)
            .join(Recipient, Subscription.recipient_id == Recipient.id)
            .filter(
                Subscription.active == True,
                Recipient.type == RecipientType.STREAM.value,
                Recipient.type_id == stream_id
            ))
        subscribers = result.scalars().all()
        return subscribers

    async def get_total_subscribed_user(self,
                                        db: AsyncSession, user_id: int) -> int:
        total_count_query = await db.execute(
            select(func.count(Subscription.id))
            .join(Recipient, Subscription.recipient == Recipient.id)
            .filter(Subscription.user == user_id,
                    Subscription.active == True,  # 활성화된 구독만 포함
                    Recipient.type == 2)  # 스트림 구독만 포함
        )
        total_count = total_count_query.scalar()
        return total_count

    async def get_subscribers_by_recipient(self, db: AsyncSession,
                                           recipient_id: int) -> List[
        SubscriptionBase]:
        query = (
            select(Subscription)
            .join(Recipient, Subscription.recipient == Recipient.id)
            .where(
                Recipient.id == recipient_id,
                Subscription.active == True
            )
        )

        result = await db.execute(query)
        subscriptions = result.scalars().all()

        return [SubscriptionBase.model_validate(sub) for sub in
                subscriptions]

    async def get_subscription_list(self, db: AsyncSession, user_id: int) \
            -> List[tuple[StreamBase, SubscriptionBase]]:
        result = await db.execute(
            select(
                Stream,
                Subscription
            ).distinct(Stream.id)
            .join(Recipient,
                  Recipient.id == Subscription.recipient_id)
            .join(Stream, Stream.id == Recipient.type_id)
            .filter(
                Subscription.user_id == user_id,
                Recipient.type == RecipientType.STREAM.value
            )
        )
        subscription = result.all()

        if not subscription:
            return []

        return [(StreamBase.model_validate(stream),
                 SubscriptionBase.model_validate(sub)) for stream, sub in
                subscription]


def get_subscription_crud() -> SubscriptionCRUDProtocol:
    return SubscriptionCRUD()
