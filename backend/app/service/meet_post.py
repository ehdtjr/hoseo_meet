from typing import Protocol, Optional
from sqlmodel.ext.asyncio.session import AsyncSession
from datetime import timedelta

from app.core.redis import redis_client
from app.crud.meet_post_crud import MeetPostCRUDProtocol, get_meet_post_crud
from app.crud.user_crud import UserCRUDProtocol, get_user_crud
from app.schemas.meet_post import (MeetPostBase, MeetPostCreate,
                                   MeetPostRequest, MeetPostListResponse,
                                   MeetPostResponse)
from app.schemas.stream import StreamCreate, StreamRead
from app.schemas.user import UserPublicRead
from app.service.stream import (StreamServiceProtocol,
                                SubscriberServiceProtocol,
                                get_stream_service,
                                get_subscription_service)


class ViewCountService:
    def __init__(self, meet_post_crud: MeetPostCRUDProtocol, ttl_hours: int = 24):
        self.meet_post_crud = meet_post_crud
        self.ttl = timedelta(hours=ttl_hours)

    async def increase_view_count(self, db: AsyncSession, meet_post_id: int, ip_address: str):
        """
        Redis를 이용해 특정 (meet_post_id, ip_address)에 대한 조회수 증가를
        24시간(기본) 내 1회로 제한하는 로직.
        """
        key = f"meet_post_view:{meet_post_id}:{ip_address}"
        exists = await redis_client.redis.exists(key)
        if exists:
            # 이미 본 적 있는 IP -> 조회수 증가 없음
            return

        # 조회수 증가
        meet_post = await self.meet_post_crud.get(db, meet_post_id)
        if meet_post:
            meet_post.page_views += 1
            meet_post = MeetPostBase.model_validate(meet_post)
            await self.meet_post_crud.update(db, meet_post)
            # Redis에 키 저장 + TTL 설정
            await redis_client.redis.set(key, 1, ex=int(self.ttl.total_seconds()))


class MeetPostServiceProtocol(Protocol):
    async def create_meet_post(self, db: AsyncSession,
                               meet_post: MeetPostRequest, user_id: int) -> MeetPostBase:
        ...

    async def get_filtered_meet_posts(self, db: AsyncSession,
                                      title: Optional[str] = None,
                                      meet_post_type: Optional[str] = None,
                                      content: Optional[str] = None,
                                      skip: int = 0,
                                      limit: int = 10
                                      ) -> Optional[list[MeetPostBase]]:
        ...

    async def get_detail_meet_post(self, db: AsyncSession, meet_post_id: int,
                                   ip_address: str) -> Optional[MeetPostResponse]:
        ...

    async def subscribe_to_meet_post(self, db: AsyncSession,
                                     user_id: int, meet_post_id: int) -> bool:
        ...


class MeetPostService(MeetPostServiceProtocol):
    def __init__(
        self,
        meet_post_crud: MeetPostCRUDProtocol,
        stream_service: StreamServiceProtocol,
        subscriber_service: SubscriberServiceProtocol,
        user_crud: UserCRUDProtocol,
        view_count_service: ViewCountService
    ):
        self.meet_post_crud = meet_post_crud
        self.stream_service = stream_service
        self.subscriber_service = subscriber_service
        self.user_crud = user_crud
        self.view_count_service = view_count_service  # 오타 수정: vew_count_service -> view_count_service

    async def create_meet_post(
        self, db: AsyncSession,
        meet_post: MeetPostRequest,
        user_id: int
    ) -> MeetPostBase:
        """
        만남 게시판을 생성하고 관련 채팅방을 만든 뒤 사용자 구독까지 처리
        """
        create_stream_data = StreamCreate(
            name=meet_post.title,
            type=meet_post.type,
            creator_id=user_id,
        )
        create_stream: StreamRead = await self.stream_service.create_stream(db, create_stream_data)

        create_meet_post_data = MeetPostCreate(
            title=meet_post.title,
            author_id=user_id,
            stream_id=create_stream.id,
            type=meet_post.type,
            content=meet_post.content,
            max_people=meet_post.max_people,
        )
        create_meet_post = await self.meet_post_crud.create(db, create_meet_post_data)

        await self.subscriber_service.subscribe(db=db, user_id=user_id, stream_id=create_stream.id)
        return create_meet_post

    async def get_filtered_meet_posts(
        self,
        db: AsyncSession,
        title: Optional[str] = None,
        meet_post_type: Optional[str] = None,
        content: Optional[str] = None,
        skip: int = 0,
        limit: int = 10
    ) -> Optional[list[MeetPostListResponse]]:
        """
        필터 조건에 맞는 meet_post를 조회하고 구독자 수, 작성자 정보 등을 포함한 응답 반환
        """
        result = []
        filtered_meet_posts = await self.meet_post_crud.get_filtered_posts(db, title, meet_post_type, content, skip, limit)

        for meet_post in filtered_meet_posts:
            subscribers = await self.subscriber_service.get_subscribers(db, meet_post.stream_id)
            author = await self.user_crud.get(db, meet_post.author_id)
            author_public = UserPublicRead.model_validate(author)

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

    async def subscribe_to_meet_post(
        self,
        db: AsyncSession,
        user_id: int,
        meet_post_id: int
    ) -> bool:
        """
        meet_post에 사용자를 구독시키는 로직:
        - 게시글 존재 확인
        - 최대 인원 수 초과 시 에러
        - 이미 구독했을 시 에러
        """
        meet_post = await self.meet_post_crud.get(db, meet_post_id)
        if meet_post is None:
            raise ValueError("해당 게시글을 찾을 수 없습니다.")

        current_people = await self.subscriber_service.get_subscribers(db, meet_post.stream_id)
        if len(current_people) >= meet_post.max_people:
            raise ValueError("참가 가능한 인원을 초과했습니다.")

        if user_id in current_people:
            raise ValueError("이미 참가한 사용자입니다.")

        await self.subscriber_service.subscribe(db, user_id, meet_post.stream_id)
        return True

    async def get_detail_meet_post(
        self,
        db: AsyncSession,
        meet_post_id: int,
        ip_address: str
    ) -> Optional[MeetPostResponse]:
        """
        상세 meet_post 조회 시 조회수 증가(하루 1회), 작성자 및 기타 정보 반환
        """
        # 조회수 증가 시도
        await self.view_count_service.increase_view_count(db, meet_post_id,
                                                          ip_address)

        meet_post:MeetPostBase = await self.meet_post_crud.get(db, meet_post_id)
        if meet_post is None:
            return None

        author = await self.user_crud.get(db, meet_post.author_id)
        author_public = UserPublicRead.model_validate(author)

        subscribers = await self.subscriber_service.get_subscribers(
            db,
            meet_post.stream_id
            )

        return MeetPostResponse(
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


def get_meet_post_service() -> MeetPostServiceProtocol:
    # 여기서 모든 의존성 주입
    view_count_service = ViewCountService(meet_post_crud=get_meet_post_crud())

    return MeetPostService(
        meet_post_crud=get_meet_post_crud(),
        stream_service=get_stream_service(),
        subscriber_service=get_subscription_service(),
        user_crud=get_user_crud(),
        view_count_service=view_count_service
    )
