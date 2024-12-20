from typing import Protocol, Optional

from sqlmodel.ext.asyncio.session import AsyncSession

from app.crud.meet_post_crud import MeetPostCRUDProtocol, get_meet_post_crud
from app.crud.user_crud import UserCRUDProtocol, get_user_crud
from app.schemas.meet_post import MeetPostBase, MeetPostCreate, \
    MeetPostRequest, MeetPostListResponse
from app.schemas.stream import StreamCreate, StreamRead
from app.schemas.user import UserPublicRead
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
                                      meet_post_type: Optional[str] = None,
                                      content: Optional[str] = None,
                                      skip: int = 0,
                                      limit: int = 10
                                      ) -> Optional[list[MeetPostBase]]:
        pass

    async def subscribe_to_meet_post(self, db: AsyncSession,
                                     user_id: int, meet_post_id: int) -> bool:
        pass


class MeetPostService(MeetPostServiceProtocol):
    def __init__(self, meet_post_crud: MeetPostCRUDProtocol,
                 stream_service: StreamServiceProtocol,
                 subscriber_service: SubscriberServiceProtocol,
                 user_crud: UserCRUDProtocol
                 ):
        self.meet_post_crud = meet_post_crud
        self.stream_service = stream_service
        self.subscriber_service = subscriber_service
        self.user_crud = user_crud

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
                                      meet_post_type: Optional[str] = None,
                                      content: Optional[str] = None,
                                      skip: int = 0,
                                      limit: int = 10
                                      ) -> Optional[list[MeetPostListResponse]]:

        result = []
        filtered_meet_posts = await self.meet_post_crud.get_filtered_posts(
            db, title, meet_post_type, content, skip, limit)

        for meet_post in filtered_meet_posts:
            subscribers = await self.subscriber_service.get_subscribers(
            db, meet_post.stream_id)

            author = await self.user_crud.get(db, meet_post.author_id)
            author_public = UserPublicRead.model_validate(author)

            # MeetPostResponse 인스턴스를 생성하면서 구독자 수를 포함
            meet_post_response = MeetPostListResponse(
                id=meet_post.id,
                title=meet_post.title,
                type=meet_post.type,
                author=author_public,
                stream_id=meet_post.stream_id,
                content=meet_post.content,
                page_views=meet_post.page_views,
                created_at=meet_post.created_at,
                max_people=meet_post.max_people,
                current_people=len(subscribers)
            )
            result.append(meet_post_response)

        return result

    async def subscribe_to_meet_post(self, db: AsyncSession,
         user_id: int, meet_post_id: int) -> bool:

        """
          게시글의 최대 인원수를 확인하고, 넘지 않았다면 구독자 추가
          - 게시글 존재 여부 확인
          - 최대 인원수 체크 및 예외 처리
          - 중복 구독 여부 체크 및 예외 처리
          """

        meet_post:MeetPostBase = await self.meet_post_crud.get(db, meet_post_id)

        if meet_post is None:
            raise ValueError("해당 게시글을 찾을 수 없습니다.")

        current_people = await self.subscriber_service.get_subscribers(db,
        meet_post.stream_id)

        if len(current_people) >= meet_post.max_people:
            raise ValueError("참가 가능한 인원을 초과했습니다.")

        if user_id in current_people:
            raise ValueError("이미 참가한 사용자입니다.")

        await self.subscriber_service.subscribe(db, user_id,
             meet_post.stream_id)
        return True


def get_meet_post_service() -> MeetPostServiceProtocol:
    return MeetPostService(
        meet_post_crud=get_meet_post_crud(),
        stream_service=get_stream_service(),
        subscriber_service=get_subscription_service(),
        user_crud = get_user_crud()
    )
