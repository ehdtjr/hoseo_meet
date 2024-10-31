from typing import Protocol, Optional

from sqlmodel.ext.asyncio.session import AsyncSession

from app.crud.meet_post_crud import MeetPostCRUDProtocol, get_meet_post_crud
from app.schemas.meet_post_schemas import MeetPostBase, MeetPostCreate, \
    MeetPostRequest
from app.schemas.stream import StreamCreate, StreamRead
from app.service.stream import (StreamServiceProtocol,
                                SubscriberServiceProtocol,
                                get_stream_service,
                                get_subscription_service)


class MeetPostServiceProtocol(Protocol):
    async def create_meet_post(self, db: AsyncSession,
                               meet_post: MeetPostRequest, user_id: int) -> (
            MeetPostBase):
        pass

    async def get_filtered_meet_posts(self, db: AsyncSession,
                                      title: Optional[str] = None,
                                      post_type: Optional[str] = None,
                                      content: Optional[str] = None,
                                      skip: int = 0,
                                      limit: int = 10
                                      ) -> Optional[list[MeetPostBase]]:
        pass


class MeetPostService(MeetPostServiceProtocol):
    def __init__(self, meet_post_crud: MeetPostCRUDProtocol,
                 stream_service: StreamServiceProtocol,
                 subscriber_service: SubscriberServiceProtocol):
        self.meet_post_crud = meet_post_crud
        self.stream_service = stream_service
        self.subscriber_service = subscriber_service

    async def create_meet_post(self, db: AsyncSession,
                               meet_post: MeetPostRequest, user_id: int) -> (
            MeetPostBase):
        """
            만남 게시판 생성
            채팅방 생성
            채팅방 구독
        """
        # 채팅방 생성
        create_stream_data = StreamCreate(
            name=meet_post.title,
            type=meet_post.type,
            creator_id=user_id,
        )
        create_stream: StreamRead = await self.stream_service.create_stream(
            db, create_stream_data)

        # 만남 게시판 생성
        create_meet_post_data = MeetPostCreate(
            title=meet_post.title,
            author_id=user_id,
            stream_id=create_stream.id,
            type=meet_post.type,
            content=meet_post.content,
            max_people=meet_post.max_people,
        )
        create_meet_post = await self.meet_post_crud.create(
            db, create_meet_post_data)

        # 채팅방 구독
        await self.subscriber_service.subscribe(db=db,
                                                user_id=user_id,
                                                stream_id=create_stream.id)

        return create_meet_post

    async def get_filtered_meet_posts(self, db: AsyncSession,
                                        title: Optional[str] = None,
                                        post_type: Optional[str] = None,
                                        content: Optional[str] = None,
                                        skip: int = 0,
                                        limit: int = 10
                                        ) -> Optional[list[MeetPostBase]]:
        return await self.meet_post_crud.get_filtered_posts(
                db, title, post_type, content, skip, limit)


def get_meet_post_service() -> MeetPostServiceProtocol:
    return MeetPostService(
        meet_post_crud=get_meet_post_crud(),
        stream_service=get_stream_service(),
        subscriber_service=get_subscription_service()
    )
