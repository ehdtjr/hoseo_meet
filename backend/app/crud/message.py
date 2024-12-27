from typing import List, Dict
from typing import Optional

from sqlalchemy import func
from sqlalchemy import insert
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
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
        self.recipient_id = None

    async def set_anchor(self, anchor_id: int):
        """앵커 메시지 ID 설정"""
        self.anchor_id = anchor_id
        return self

    async def filter_by_stream_id(self, stream_id: int):
        """특정 스트림에 속하는 메시지 필터링"""
        # stream_id에 해당하는 recipient_id를 직접 가져와 단순 조건으로 변경
        recipient_id = await self.db.scalar(
            select(Recipient.id).where(
                Recipient.type == RecipientType.STREAM.value,
                Recipient.type_id == stream_id
            ).limit(1)
        )

        if recipient_id is None:
            # 해당 stream_id에 해당하는 recipient가 없다면 결과 없음
            self.filter_conditions.append(Message.id == -1)  # 불가능한 조건
        else:
            self.filter_conditions.append(Message.recipient_id == recipient_id)

        return self

    async def build(self, num_before: int, num_after: int) -> List[Message]:
        """앵커 기준 이전/이후 메시지 가져오기"""
        if not self.anchor_id:
            raise ValueError("Anchor id is not set")

        # 필터 조건 적용
        query = self.query
        if self.filter_conditions:
            query = query.where(and_(*self.filter_conditions))

        # 앵커 메시지 가져오기
        # joinedload 제거 (필요 시 다시 추가)
        anchor_query = query.where(Message.id == self.anchor_id)
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

    async def send_message_create(
        self, db: AsyncSession, message: MessageCreate
    ) -> MessageBase:
        pass


class MessageCRUD(CRUDBase[Message, MessageBase], MessageCRUDProtocol):
    def __init__(self):
        super().__init__(Message, MessageBase)

    async def create(self, db: AsyncSession,
                     message: MessageCreate) -> MessageBase:
        return await super().create(db, message)

    async def get(self, db: AsyncSession, id: int) -> MessageBase:
        return await super().get(db, id)

    async def send_message_create(
        self, db: AsyncSession, message: MessageCreate
    ) -> MessageBase:
        """
        메시지 전송용으로 INSERT만 하고, refresh()는 생략하는 메서드
        """
        obj_in_data = message.model_dump()
        db_obj = self.model(**obj_in_data)
        db.add(db_obj)
        await db.flush()
        await db.commit()
        return MessageBase.model_construct(
            id=db_obj.id,
            sender_id=db_obj.sender_id,
            type=db_obj.type,
            recipient_id=db_obj.recipient_id,
            content=db_obj.content,
            rendered_content=db_obj.rendered_content,
            date_sent=db_obj.date_sent)

    async def get_stream_messages(self, db: AsyncSession, stream_id: int,
                                  anchor_id: int, num_before: int,
                                  num_after: int) -> List[MessageBase]:
        query_builder = MessageQueryBuilder(db)

        await query_builder.set_anchor(anchor_id)
        await query_builder.filter_by_stream_id(stream_id)
        messages = await query_builder.build(num_before=num_before,
                                             num_after=num_after)


        return [MessageBase.model_construct(
            id=msg.id,
            sender_id=msg.sender_id,
            type=msg.type,
            recipient_id=msg.recipient_id,
            content=msg.content,
            rendered_content = msg.rendered_content,
            date_sent=msg.date_sent,
        ) for msg in messages]


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

    async def get_unread_counts_for_messages(
        self,
        db: AsyncSession,
        message_ids: List[int]) -> Dict[int, int]:
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
            .join(Recipient, Message.recipient_id == Recipient.id)  # Recipient 테이블과 조인
            .where(
                Recipient.type == RecipientType.STREAM.value,  # Recipient가
                Recipient.type_id == stream_id,  # stream_id와 일치하는지 확인
                UserMessage.user_id == user_id  # user_id가 일치하는지 확인
            )
            .order_by(UserMessage.message_id.desc())  # 최신 메시지를 먼저 가져오기
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
        recipient_id = await db.scalar(
            select(Recipient.id)
            .where(
                Recipient.type == RecipientType.STREAM.value,
                Recipient.type_id == stream_id
            )
            .limit(1)
        )
        query = (
            select(UserMessage)
            .join(Message, UserMessage.message_id == Message.id)
            .where(
                Message.recipient_id == recipient_id,
                UserMessage.user_id == user_id
            )
            .order_by(UserMessage.message_id.asc())
            .limit(1)
        )

        result = await db.execute(query)
        oldest_message = result.scalars().first()

        if oldest_message is None:
            return None

        return UserMessageBase.model_validate(oldest_message)

    async def get_first_unread_message_in_stream(self, db: AsyncSession,
                                                 user_id: int,
                                                 stream_id: int) -> Optional[UserMessageBase]:

        recipient_id_sub = (
            select(Recipient.id)
            .where(
                Recipient.type == RecipientType.STREAM.value,
                Recipient.type_id == stream_id
            ).limit(1)
            .scalar_subquery()
        )
        # 쿼리: 특정 스트림에서 사용자가 읽지 않은 첫 번째 메시지를 가져옴
        query = (
            select(UserMessage)
            .join(Message, UserMessage.message_id == Message.id)
            .where(
                Message.recipient_id == recipient_id_sub,
                UserMessage.user_id == user_id,
                UserMessage.is_read == False
            )
            .order_by(UserMessage.message_id.asc())
            .limit(1)
        )

        # 쿼리 실행 및 결과 처리
        result = await db.execute(query)
        first_unread_message = result.scalars().first()

        # 결과가 없을 경우 None 반환
        if first_unread_message is None:
            return None

        return UserMessageBase.model_validate(first_unread_message)


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
            .join(Recipient, Message.recipient_id == Recipient.id)  # Recipient 테이블과 조인
            .where(
                Recipient.type == RecipientType.STREAM.value,  # 스트림 타입 필터링
                Recipient.type_id == stream_id,  # stream_id와 일치하는지 확인
                UserMessage.user_id == user_id,  # user_id 확인
                UserMessage.is_read == False  # 읽지 않은 메시지 필터링
            )
        )
        result = await db.execute(query)
        unread_count = result.scalar() or 0  # 결과 없으면 0으로 처리
        return unread_count

    async def mark_stream_messages_read(self, db: AsyncSession, user_id: int,
                                        stream_id: int, anchor_id: int,
                                        num_before: int, num_after: int) -> None:
        """
        특정 유저의 특정 스트림에서 앵커를 기준으로 일정 범위의 메시지를 읽음으로 표시하는 함수.
        """
        # 앵커 이전 메시지들 가져오기 (num_before 개수)
        before_query = (
            select(Message.id)
            .join(Recipient, Message.recipient_id == Recipient.id)  # Recipient 테이블과 조인
            .where(
                Recipient.type == RecipientType.STREAM.value,  # 스트림 타입 필터링
                Recipient.type_id == stream_id,  # stream_id와 일치하는지 확인
                Message.id < anchor_id  # 앵커보다 이전 메시지
            )
            .order_by(Message.id.desc())
            .limit(num_before)
        )
        before_message_ids_result = await db.execute(before_query)
        before_message_ids = before_message_ids_result.scalars().all()

        # 앵커 이후 메시지들 가져오기 (num_after 개수)
        after_query = (
            select(Message.id)
            .join(Recipient, Message.recipient_id == Recipient.id)  # Recipient 테이블과 조인
            .where(
                Recipient.type == RecipientType.STREAM.value,  # 스트림 타입 필터링
                Recipient.type_id == stream_id,  # stream_id와 일치하는지 확인
                Message.id > anchor_id  # 앵커보다 이후 메시지
            )
            .order_by(Message.id.asc())
            .limit(num_after)
        )
        after_message_ids_result = await db.execute(after_query)
        after_message_ids = after_message_ids_result.scalars().all()

        # 이전 메시지들 + 앵커 메시지 + 이후 메시지들의 ID 목록
        message_ids = list(before_message_ids) + [anchor_id] + list(after_message_ids)

        # UserMessage 테이블 업데이트 (읽음 표시)
        stmt = (
            update(UserMessage)
            .where(
                UserMessage.user_id == user_id,  # 해당 유저의 메시지
                UserMessage.message_id.in_(message_ids)  # 조회한 메시지 목록에 해당하는 것
            )
            .values(is_read=True)  # 읽음으로 표시
        )
        await db.execute(stmt)
        await db.commit()

    async def get_unread_counts_for_messages(
        self,
        db: AsyncSession,
        message_ids: List[int]) -> Dict[int, int]:

        if not message_ids:
            return {}

        query = (
            select(
                UserMessage.message_id,
                func.count(UserMessage.id).label("unread_count")
                )
                .where(
                    UserMessage.message_id.in_(message_ids),
                    UserMessage.is_read == False,
                ).group_by(UserMessage.message_id)
        )
        result = await db.execute(query)
        row = result.all()
        unread_map = {r.message_id: r.unread_count for r in row}
        return unread_map


def get_user_message_crud() -> UserMessageCRUDProtocol:
    return UserMessageCRUD()
