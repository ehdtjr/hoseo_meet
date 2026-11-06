"""Database-backed retry loop. External delivery is at least once."""
import asyncio
import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select

from app.core.config import settings
from app.core.db import async_session_maker
from app.core.redis import redis_client
from app.crud.user import UserFCMTokenCRUD
from app.models.message_outbox import MessageOutbox
from app.service.message_fcm import send_fcm_isolated
from app.service.stream import RedisActiveStreamService

logger = logging.getLogger(__name__)

# Atomic enqueue + deduplication covers an ambiguous XADD response or a crash
# before PostgreSQL records success. Retain markers for seven days.
ENQUEUE_ONCE = """
if redis.call('EXISTS', KEYS[2]) == 1 then return 0 end
redis.call('XADD', KEYS[1], '*', 'type', 'stream', 'data', ARGV[1])
redis.call('SET', KEYS[2], '1', 'EX', 604800)
return 1
"""


class MessageOutboxDelivery:
    async def deliver(self, db, row: MessageOutbox) -> str:
        active = await RedisActiveStreamService().get_active_stream(row.user_id)
        if active == row.stream_id:
            await redis_client.redis.eval(
                ENQUEUE_ONCE, 2, f"queue:{row.user_id}",
                f"message-delivered:{row.message_id}:{row.user_id}", row.payload)
            return "redis_accepted"
        if not settings.FCM_ENABLED:
            return "fcm_disabled"
        return "fcm_pending"

    async def deliver_fcm(self, db, row: MessageOutbox) -> str:
        # Presence may have changed while the push waited in its own queue.
        outcome = await self.deliver(db, row)
        if outcome != "fcm_pending":
            return outcome
        tokens = await UserFCMTokenCRUD().get_user_fcm_tokens_by_user_ids(db, [row.user_id])
        if not tokens:
            return "no_fcm_token"
        await send_fcm_isolated([token.fcm_token for token in tokens], row.payload)
        return "fcm_accepted"


class MessageOutboxWorker:
    def __init__(self, session_factory=async_session_maker, delivery=None):
        self.session_factory = session_factory
        self.delivery = delivery or MessageOutboxDelivery()

    async def process_one(self, channel: str = "route") -> bool:
        async with self.session_factory() as db:
            async with db.begin():
                # Concurrent API processes can drain the queue safely. A process
                # exit releases the row lock and leaves the event pending.
                row = await db.scalar(select(MessageOutbox).where(
                    MessageOutbox.completed_at.is_(None),
                    MessageOutbox.channel == channel,
                    MessageOutbox.available_at <= func.now(),
                ).order_by(MessageOutbox.available_at, MessageOutbox.id)
                    .with_for_update(skip_locked=True).limit(1))
                if row is None:
                    return False
                row.attempts += 1
                try:
                    # Roll back any delivery-side DB failure without losing the
                    # outer transaction's retry metadata.
                    async with db.begin_nested():
                        deliver = (self.delivery.deliver_fcm if channel == "fcm"
                                   else self.delivery.deliver)
                        outcome = await asyncio.wait_for(deliver(db, row), timeout=30)
                except Exception as error:
                    row.last_error = type(error).__name__[:64]
                    row.available_at = datetime.now(timezone.utc) + timedelta(
                        seconds=min(300, 2 ** min(row.attempts, 9)))
                    logger.warning("Message delivery pending outbox_id=%s attempts=%s error_type=%s",
                                   row.id, row.attempts, row.last_error)
                else:
                    row.last_error = None
                    if outcome == "fcm_pending":
                        row.channel = "fcm"
                        row.available_at = datetime.now(timezone.utc)
                    else:
                        row.outcome = outcome
                        row.completed_at = datetime.now(timezone.utc)
        return True

    async def run(self) -> None:
        # A stalled provider must never occupy the Redis routing worker.
        tasks = [asyncio.create_task(self._run_channel(channel))
                 for channel in ("route", "fcm")]
        try:
            await asyncio.gather(*tasks)
        finally:
            for task in tasks:
                task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)

    async def _run_channel(self, channel: str) -> None:
        while True:
            try:
                if not await self.process_one(channel):
                    await asyncio.sleep(1)
            except Exception as error:
                # No exception text: provider errors can contain message/token data.
                logger.warning("Message outbox poll failed error_type=%s", type(error).__name__)
                await asyncio.sleep(5)
