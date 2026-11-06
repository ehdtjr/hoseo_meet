"""Matching is a single PostgreSQL transaction, including durable queue state.

Redis continues to transport chat events, but is not a second source of queue
truth. This avoids losing users between a Redis pop and a failed DB commit.
"""
from datetime import timedelta
from typing import Literal

from sqlalchemy import delete, func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.randomchat.schemas import QueueStatus
from app.models import RandomChatQueue, Recipient, Stream, Subscription, User
from app.schemas.recipient import RecipientType

WAIT_SECONDS = 90
# Transaction-scoped, shared across workers; released on commit, rollback or
# connection loss. No expiring distributed lease can permit a second matcher.
MATCH_LOCK_ID = 250025


class RandomChatService:
    async def join(self, db: AsyncSession, user_id: int) -> QueueStatus:
        return await self._change(db, user_id, "join")

    async def leave(self, db: AsyncSession, user_id: int) -> QueueStatus:
        return await self._change(db, user_id, "leave")

    async def status(self, db: AsyncSession, user_id: int) -> QueueStatus:
        return await self._change(db, user_id, "status")

    async def _change(
        self, db: AsyncSession, user_id: int,
        action: Literal["join", "leave", "status"],
    ) -> QueueStatus:
        # Authentication may already have opened a transaction on this request's
        # session. Own its final commit/rollback; generic CRUD commits each step.
        try:
            await db.execute(text("SET LOCAL lock_timeout = '5s'"))
            await db.execute(
                text("SELECT pg_advisory_xact_lock(:key)"), {"key": MATCH_LOCK_ID}
            )
            now = (await db.execute(select(func.clock_timestamp()))).scalar_one()
            if action == "join":
                # Keep eligibility stable until this transaction commits. Admin
                # updates do not acquire the queue's advisory lock.
                eligible = (await db.execute(
                    select(User.id).where(
                        User.id == user_id, User.is_active.is_(True),
                        User.is_verified.is_(True),
                    ).with_for_update(read=True)
                )).scalar_one_or_none()
                if eligible is None:
                    raise PermissionError("An active verified account is required")
            entry = await db.get(RandomChatQueue, user_id, populate_existing=True)
            if entry is not None and entry.stream_id is not None:
                active = (await db.execute(
                    select(Subscription.id)
                    .join(Stream, Stream.recipient_id == Subscription.recipient_id)
                    .where(Stream.id == entry.stream_id,
                           Subscription.user_id == user_id,
                           Subscription.active.is_(True))
                )).scalar_one_or_none()
                if active is not None:
                    result = QueueStatus(status="matched", stream_id=entry.stream_id)
                    await db.commit()
                    return result
                await db.delete(entry)
                await db.flush()
                entry = None

            if entry is not None and entry.expires_at <= now:
                await db.delete(entry)
                await db.flush()
                entry = None

            if action == "leave":
                if entry is not None:
                    await db.delete(entry)
                result = QueueStatus(status="idle")
            elif action == "status":
                if entry is not None:
                    entry.expires_at = now + timedelta(seconds=WAIT_SECONDS)
                result = QueueStatus(status="waiting" if entry is not None else "idle")
            else:
                # FIFO position survives retries and heartbeats. Matched results
                # remain durable until the user leaves that chat subscription.
                eligible_users = select(User.id).where(
                    User.is_active.is_(True), User.is_verified.is_(True)
                )
                await db.execute(delete(RandomChatQueue).where(
                    RandomChatQueue.stream_id.is_(None),
                    (RandomChatQueue.expires_at <= now)
                    | RandomChatQueue.user_id.not_in(eligible_users),
                ))
                if entry is None:
                    entry = RandomChatQueue(
                        user_id=user_id, queued_at=now,
                        expires_at=now + timedelta(seconds=WAIT_SECONDS),
                    )
                    db.add(entry)
                else:
                    entry.expires_at = now + timedelta(seconds=WAIT_SECONDS)
                await db.flush()
                peer = (await db.execute(
                    select(RandomChatQueue)
                    .join(User, User.id == RandomChatQueue.user_id)
                    .where(RandomChatQueue.stream_id.is_(None),
                           RandomChatQueue.user_id != user_id,
                           User.is_active.is_(True), User.is_verified.is_(True))
                    .order_by(RandomChatQueue.queued_at, RandomChatQueue.user_id)
                    .limit(1)
                    .with_for_update(read=True, of=User)
                )).scalar_one_or_none()
                if peer is None:
                    result = QueueStatus(status="waiting")
                else:
                    stream_id = await self._create_match(db, peer.user_id, user_id)
                    peer.stream_id = entry.stream_id = stream_id
                    result = QueueStatus(status="matched", stream_id=stream_id)
            await db.commit()
            return result
        except BaseException:
            # Request cancellation also rolls back half-created rooms and queue
            # changes. If a commit reply is lost, retry reads the durable result.
            await db.rollback()
            raise

    async def _create_match(self, db: AsyncSession, first: int, second: int) -> int:
        stream = Stream(name="랜덤 채팅", type="random", creator_id=first)
        db.add(stream)
        await db.flush()
        recipient = Recipient(type=RecipientType.STREAM.value, type_id=stream.id)
        db.add(recipient)
        await db.flush()
        stream.recipient_id = recipient.id
        db.add_all([
            Subscription(user_id=user_id, recipient_id=recipient.id,
                         active=True, is_user_active=True, is_muted=False)
            for user_id in (first, second)
        ])
        await db.flush()
        return stream.id


def get_random_chat_service() -> RandomChatService:
    return RandomChatService()
