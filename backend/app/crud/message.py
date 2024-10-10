from typing import List
from typing import Optional

from sqlalchemy import func
from sqlalchemy import insert
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import joinedload
from sqlalchemy.sql import and_

from app.crud.base import CRUDBase
from app.models import Recipient
from app.models.message import Message, UserMessage
from app.schemas.message import MessageBase, MessageCreate, UserMessageBase, \
    UserMessageCreate
from app.schemas.recipient import RecipientType


class MessageQueryBuilder:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.query = select(Message)
        self.filter_conditions = []
        self.anchor_id = None

    async def set_anchor(self, anchor_id: int):
        """앵커 메시지 ID 설정"""
        self.anchor_id = anchor_id
        return self

    async def filter_by_stream_id(self, stream_id: int):
        """특정 스트림에 속하는 메시지 필터링"""
        recipient_subquery = select(Recipient.id).where(
            Recipient.type == RecipientType.STREAM.value,  # 스트림 타입을 기준으로 필터링
            Recipient.type_id == stream_id
        ).subquery()
        self.filter_conditions.append(
            Message.recipient_id.in_(recipient_subquery)
        )
        return self

    async def filter_by_last_received(self, user_id: int, last_message_id: int):
        """유저 기준으로, 특정 메시지 ID보다 큰 메시지 필터링"""
        self.filter_conditions.append(
            (UserMessage.user_id == user_id) & (
                        UserMessage.message_id > last_message_id)
        )
        return self

    async def build(self, num_before: int, num_after: int) -> List[Message]:
        """앵커 기준 이전/이후 메시지 가져오기"""
        if not self.anchor_id:
            raise ValueError("Anchor id is not set")

        # 필터 조건 적용
        query = self.query
        if self.filter_conditions:
            query = query.where(and_(*self.filter_conditions))

        # 앵커 메시지 가져오기 (미리 message 객체 로드)
        anchor_query = query.where(Message.id == self.anchor_id).options(
            joinedload(Message.user_messages)  # 올바른 엔티티 로딩 옵션
        )
        anchor_message = await self.db.scalar(anchor_query)
        if not anchor_message:
            return []

        # 앵커 이전 메시지 가져오기
        before_query = (
            query.where(Message.id < self.anchor_id)
            .order_by(Message.id.desc())
            .limit(num_before)
        )
        messages_before = list((await self.db.execute(before_query)).scalars())
        messages_before.reverse()

        # 앵커 이후 메시지 가져오기
        after_query = (
            query.where(Message.id > self.anchor_id)
            .order_by(Message.id.asc())
            .limit(num_after)
        )
        messages_after = list((await self.db.execute(after_query)).scalars())

        # 이전 메시지 + 앵커 메시지 + 이후 메시지로 리스트 구성
        all_messages = messages_before + [anchor_message] + messages_after
        return all_messages


class MessageCRUDProtocol:
    async def create(self, db: AsyncSession,
                     message: MessageCreate) -> MessageBase:
        pass

    async def get(self, db: AsyncSession, id: int) -> MessageBase:
        pass

    async def get_stream_messages(self, db: AsyncSession, stream_id: int,
                                  anchor_id: int, num_before: int,
                                  num_after: int) -> List[MessageBase]:
        pass


class MessageCRUD(CRUDBase[Message, MessageBase], MessageCRUDProtocol):
    def __init__(self):
        super().__init__(Message, MessageBase)

    async def create(self, db: AsyncSession,
                     message: MessageCreate) -> MessageBase:
        return await super().create(db, message)

    async def get(self, db: AsyncSession, id: int) -> MessageBase:
        return await super().get(db, id)

    async def get_stream_messages(self, db: AsyncSession, stream_id: int,
                                  anchor_id: int, num_before: int,
                                  num_after: int) -> List[MessageBase]:
        query_builder = MessageQueryBuilder(db)

        await query_builder.set_anchor(anchor_id)
        await query_builder.filter_by_stream_id(stream_id)
        messages = await query_builder.build(num_before=num_before,
                                             num_after=num_after)

        return [MessageBase.model_validate(message) for message in messages]


def get_message_crud() -> MessageCRUDProtocol:
    return MessageCRUD()


class UserMessageCRUDProtocol:
    async def create(self, db: AsyncSession,
                     user_message: UserMessageCreate) -> UserMessageBase:
        pass

    async def get(self, db: AsyncSession, id: int) -> UserMessageBase:
        pass

    async def update(self, db: AsyncSession, id: int,
                     is_read: bool) -> UserMessageBase:
        pass

    async def bulk_create(self, db: AsyncSession,
                          user_messages: list[dict]) -> None:
        pass

    async def get_newest_message_in_stream(self, db: AsyncSession,
                                           user_id: int,
                                           stream_id: int) -> UserMessageBase:
        pass

    async def get_oldest_message_in_stream(self, db: AsyncSession,
                                           user_id: int,
                                           stream_id: int) -> Optional[
        UserMessageBase]:
        pass

    async def get_first_unread_message_in_stream(self, db: AsyncSession,
                                                 user_id: int,
                                                 stream_id: int) -> (
            Optional[UserMessageBase]):
        pass

    async def get_first_unread_message_in_stream_count(self,
                                                       db: AsyncSession,
                                                       user_id: int,
                                                       stream_id: int) -> (int):
        pass

    async def mark_stream_messages_read(self, db: AsyncSession, user_id: int,
                                        stream_id: int, anchor_id: int,
                                        num_before: int,
                                        num_after: int) -> None:
        pass


class UserMessageCRUD(CRUDBase[UserMessage, UserMessageBase],
                      UserMessageCRUDProtocol):
    def __init__(self):
        super().__init__(UserMessage, UserMessageBase)

    async def create(self, db: AsyncSession,
                     user_message: UserMessageBase) -> UserMessageBase:
        return await super().create(db, user_message)

    async def get(self, db: AsyncSession, id: int) -> UserMessageBase:
        return await super().get(db, id)

    async def bulk_create(self, db: AsyncSession,
                          user_messages: list[dict]) -> None:
        stmt = insert(UserMessage).values(user_messages)
        await db.execute(stmt)
        await db.commit()

    async def get_newest_message_in_stream(self, db: AsyncSession,
                                           user_id: int,
                                           stream_id: int) -> (
            Optional[UserMessageBase]):
        query = (
            select(UserMessage)
            .join(Message, UserMessage.message_id == Message.id)
            .where(Message.recipient_id == stream_id,
                   UserMessage.user_id == user_id)
            .order_by(UserMessage.message_id.desc())
            .limit(1)
        )
        result = await db.execute(query)
        result = result.scalars().first()
        if result is None:
            return None
        return UserMessageBase.model_validate(result)

    async def get_oldest_message_in_stream(self, db: AsyncSession,
                                           user_id: int,
                                           stream_id: int) -> (
            Optional[UserMessageBase]):
        query = (
            select(UserMessage)
            .join(Message, UserMessage.message_id == Message.id)
            .where(Message.recipient_id == stream_id,
                   UserMessage.user_id == user_id)
            .order_by(UserMessage.message_id.asc())
            .limit(1)
        )
        result = await db.execute(query)
        result = result.scalars().first()
        if result is None:
            return None
        return UserMessageBase.model_validate(result)

    async def get_first_unread_message_in_stream(self, db: AsyncSession,
                                                 user_id: int,
                                                 stream_id: int) -> (
            Optional[UserMessageBase]):
        query = (
            select(UserMessage)
            .join(Message, UserMessage.message_id == Message.id)
            .where(UserMessage.user_id == user_id,
                   UserMessage.is_read == False,
                   Message.recipient_id == stream_id)
            .order_by(UserMessage.message_id.asc())
            .limit(1)
        )
        result = await db.execute(query)
        result = result.scalars().first()
        if result is None:
            return None
        return UserMessageBase.model_validate(result)

    async def get_first_unread_message_in_stream_count(self,
                                                       db: AsyncSession,
                                                       user_id: int,
                                                       stream_id: int) -> int:
        """
        주어진 스트림에서 해당 유저가 읽지 않은 메시지의 수를 반환하는 함수.
        """
        # 안 읽은 메시지 수 조회 쿼리
        query = (
            select(func.count(UserMessage.id))
            .join(Message, UserMessage.message_id == Message.id)
            .where(
                UserMessage.user_id == user_id,
                UserMessage.is_read == False,
                Message.recipient_id == stream_id
            )
        )
        result = await db.execute(query)
        unread_count = result.scalar() or 0  # 결과 없으면 0으로 처리
        return unread_count

    async def mark_stream_messages_read(self, db: AsyncSession, user_id: int,
                                        stream_id: int, anchor_id: int,
                                        num_before: int,
                                        num_after: int) -> None:
        """
        특정 유저의 특정 스트림에서 앵커를 기준으로 일정 범위의 메시지를 읽음으로 표시하는 함수.
        """
        # 앵커 이전 메시지들 가져오기 (num_before 개수)
        before_query = (
            select(Message.id)
            .where(
                Message.recipient_id == stream_id,
                Message.id < anchor_id
            )
            .order_by(Message.id.desc())
            .limit(num_before)
        )
        before_message_ids_result = await db.execute(before_query)
        before_message_ids = before_message_ids_result.scalars().all()

        # 앵커 이후 메시지들 가져오기 (num_after 개수)
        after_query = (
            select(Message.id)
            .where(
                Message.recipient_id == stream_id,
                Message.id > anchor_id
            )
            .order_by(Message.id.asc())
            .limit(num_after)
        )
        after_message_ids_result = await db.execute(after_query)
        after_message_ids = after_message_ids_result.scalars().all()

        message_ids = list(before_message_ids) + [anchor_id] + list(
            after_message_ids)

        # UserMessage 테이블 업데이트 (읽음 표시)
        stmt = (
            update(UserMessage)
            .where(
                UserMessage.user_id == user_id,
                UserMessage.message_id.in_(message_ids)
            )
            .values(is_read=True)
        )
        await db.execute(stmt)
        await db.commit()


def get_user_message_crud() -> UserMessageCRUDProtocol:
    return UserMessageCRUD()

