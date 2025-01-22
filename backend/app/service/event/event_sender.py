import logging
from dataclasses import dataclass
from typing import List

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import redis_client
from app.crud.user import UserFCMTokenCRUDProtocol, \
    get_user_fcm_token_crud
from app.schemas.event import EventBase
from app.service.event.fcm.event_fcm_factory import FCMEventStrategyFactory
from app.service.event.fcm.event_fcm_strategy import FCMEventSelectionContext, \
    FCMEventsSelectionContext

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class EventSenderProtocol:
    async def send_event(self, db: AsyncSession, user_id: int,
                         event_data: EventBase):
        pass

    async def send_events(self, db: AsyncSession,
                          user_ids: list[int], event_data: EventBase):
        pass


class WebSocketEventSender(EventSenderProtocol):
    async def send_event(self, db: AsyncSession, user_id: int, event_data:
    EventBase):
        if not event_data:
            raise ValueError("이벤트 데이터가 비어 있거나 유효하지 않습니다")
        await redis_client.redis.xadd(f"queue:{user_id}", event_data.model_dump())

    async def send_events(self, db:AsyncSession,
                          user_ids: list[int], event_data: EventBase):
        if not event_data:
            raise ValueError("이벤트 데이터가 비어 있거나 유효하지 않습니다.")
        data = event_data.model_dump()  # 미리 dict 변환
        async with redis_client.redis.pipeline(transaction=False) as pipe:
            for user_id in user_ids:
                pipe.xadd(f"queue:{user_id}", data)
            await pipe.execute()


class FCMEventSender(EventSenderProtocol):
    async def send_event(self, db: AsyncSession, user_id: int, event_data:
    EventBase):

        fcm_crud: UserFCMTokenCRUDProtocol = get_user_fcm_token_crud()
        token = await fcm_crud.get_user_fcm_token_by_user_id(db, user_id)

        strategy = FCMEventStrategyFactory.get_strategy(event_data.type)
        context = FCMEventSelectionContext(
            token_id=token.fcm_token,
            event=event_data
        )
        strategy.send_notification(context)

    # TODO: Implement send_events method
    async def send_events(self, db:AsyncSession,
                          user_ids: list[int], event_data: EventBase):

        print("[DEBUG] Entering FCMEventSender.send_events")
        print("[DEBUG] user_ids:", user_ids)

        if (user_ids is None) or (len(user_ids) == 0):
            return

        fcm_crud: UserFCMTokenCRUDProtocol = get_user_fcm_token_crud()
        tokens = await fcm_crud.get_user_fcm_tokens_by_user_ids(db, user_ids)
        tokens_ids = [token.fcm_token for token in tokens]

        if (tokens_ids is None) or (len(tokens_ids) == 0):
            return

        strategy = FCMEventStrategyFactory.get_strategy(event_data.type)
        context = FCMEventsSelectionContext(
            token_ids=tokens_ids,
            event=event_data
        )
        strategy.sends_notifications(context)


class NoopEventSender(EventSenderProtocol):
    async def send_event(self, db: AsyncSession, user_id: int,
                         event_data: EventBase):
        pass

    async def send_events(self, db:AsyncSession,
                          user_ids: list[int], event_data: EventBase):
        pass