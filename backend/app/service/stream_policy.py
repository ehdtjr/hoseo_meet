"""Public room access policy; raw subscription CRUD is for trusted internal use."""

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundException, PermissionDeniedException
from app.models import Recipient, Stream, Subscription, User
from app.models.meet_post import MeetPost
from app.models.story_post import StoryPost
from app.schemas.recipient import RecipientType


class StreamAccessPolicy:
    async def lock_join_target(self, db: AsyncSession, user_id: int,
                               stream_id: int) -> tuple[int, int | None]:
        # Every public join/rejoin locks the same row until subscription commit.
        # PostgreSQL READ COMMITTED then sees the preceding join in the count.
        stream = (await db.execute(
            select(Stream).where(Stream.id == stream_id).with_for_update()
            .execution_options(populate_existing=True)
        )).scalar_one_or_none()
        if stream is None:
            raise NotFoundException("채팅방을 찾을 수 없습니다.")

        active_user = await db.scalar(select(User.id).where(
            User.id == user_id, User.is_active.is_(True)))
        if active_user is None:
            raise PermissionDeniedException("활성 사용자만 참가할 수 있습니다.")

        recipient_id = await db.scalar(select(Recipient.id).where(
            Recipient.id == stream.recipient_id,
            Recipient.type == RecipientType.STREAM.value,
            Recipient.type_id == stream.id,
        ))
        if recipient_id is None:
            raise NotFoundException("채팅방 수신자를 찾을 수 없습니다.")

        if stream.type in {"meet", "delivery", "taxi", "carpool"}:
            post = (await db.execute(select(MeetPost).where(
                MeetPost.stream_id == stream.id,
                MeetPost.type == stream.type,
            ).with_for_update().execution_options(populate_existing=True)
            )).scalar_one_or_none()
            if post is None:
                raise PermissionDeniedException("참가 가능한 모임이 없습니다.")
            return recipient_id, post.max_people

        if stream.type == "story":
            post_id = await db.scalar(select(StoryPost.id).where(
                StoryPost.stream_id == stream.id,
                StoryPost.expires_at > func.now(),
            ).with_for_update())
            if post_id is None:
                raise PermissionDeniedException("참가 가능한 스토리가 없습니다.")
            return recipient_id, None

        # Random matching has no public join policy yet; unknown types fail closed.
        raise PermissionDeniedException("직접 참가할 수 없는 채팅방입니다.")

    async def require_active_member(self, db: AsyncSession, user_id: int,
                                    stream_id: int) -> None:
        subscription_id = await db.scalar(
            select(Subscription.id)
            .join(Recipient, Recipient.id == Subscription.recipient_id)
            .join(Stream, Stream.recipient_id == Recipient.id)
            .join(User, User.id == Subscription.user_id)
            .where(
                Stream.id == stream_id,
                Recipient.type == RecipientType.STREAM.value,
                Recipient.type_id == stream_id,
                Subscription.user_id == user_id,
                Subscription.active.is_(True),
                Subscription.is_user_active.is_(True),
                User.is_active.is_(True),
            )
        )
        if subscription_id is None:
            raise PermissionDeniedException("현재 참가자만 위치를 전송할 수 있습니다.")
