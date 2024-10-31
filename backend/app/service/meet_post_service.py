from typing import Protocol

from sqlmodel.ext.asyncio.session import AsyncSession

from app.crud.meet_post_crud import MeetPostCRUDProtocol, get_meet_post_crud
from app.schemas.meet_post_schemas import MeetPostBase, MeetPostCreate
from app.schemas.stream import StreamCreate, StreamRead
from app.service.stream import StreamServiceProtocol, SubscriberServiceProtocol, \
    get_stream_service, get_subscription_service


class MeetPostServiceProtocol(Protocol):
    async def create_meet_post(self,db: AsyncSession, meet_post:
    MeetPostCreate) -> MeetPostBase:
        pass


class MeetPostService(MeetPostServiceProtocol):

    def __init__(self, meet_post_crud: MeetPostCRUDProtocol,
    stream_service: StreamServiceProtocol,
    subscriber_service: SubscriberServiceProtocol):
        self.meet_post_crud = meet_post_crud
        self.stream_service = stream_service
        self.subscriber_service = subscriber_service

    async def create_meet_post(self, db: AsyncSession,
         meet_post: MeetPostCreate) -> MeetPostBase:
        """
            만남 게시판 생성
            채팅방 생성
            채팅방 구독
        """
        # 만남 게시판 생성
        create_meet_post: MeetPostBase = await self.meet_post_crud.create(db,
        meet_post)

        # 채팅방 생성
        create_stream_data = StreamCreate(
            name=meet_post.title,
            type=meet_post.type,
            creator_id=meet_post.author_id,
        )
        create_stream: StreamRead = await self.stream_service.create_stream(db,
        create_stream_data)

        # 채팅방 구독
        await self.subscriber_service.subscribe(db=db,
        user_id=meet_post.author_id, stream_id=create_stream.id)

        return create_meet_post


def get_meet_post_service() -> MeetPostServiceProtocol:
    return MeetPostService(
        meet_post_crud=get_meet_post_crud(),
        stream_service=get_stream_service(),
        subscriber_service=get_subscription_service()
    )