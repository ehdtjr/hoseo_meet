from fastapi import UploadFile
from fastapi.params import Depends
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.s3 import S3Manager, get_s3_manager
from app.crud.story_post import StoryPostCRUD, get_story_post_crud
from app.schemas.story_post import StoryPostCreate, StoryPostBase, \
    StoryPostResponse, StoryPostRequest
from app.schemas.stream import StreamCreate, StreamRead
from app.service.stream import StreamService, SubscriberService, \
    get_stream_service, get_subscription_service
from app.utils.image import convert_image_to_webp
from app.utils.s3 import generate_s3_key


class StoryPostService:
    def __init__(
        self,
        story_post_crud: StoryPostCRUD,
        stream_service: StreamService,
        subscriber_service: SubscriberService,
        s3_manager: S3Manager,
    ):
        self.story_post_crud = story_post_crud
        self.stream_service = stream_service
        self.subscriber_service = subscriber_service
        self.s3_manager = s3_manager

    async def upload_image(self, user_id: int, file: UploadFile) -> str:
        unique_url = generate_s3_key(
            f"story_post/{user_id}", "story.webp",
        )
        if file.content_type == "image/webp":
            file.file.seek(0)
            image_url = await self.s3_manager.upload_file(file, unique_url)
        else:
            webp_file = convert_image_to_webp(file.file)
            image_url = await self.s3_manager.upload_byte_file(webp_file, unique_url)

        return image_url

    async def create_story_post(
        self, db: AsyncSession,
        user_id: int,
        story_request: StoryPostRequest,
    ) -> StoryPostResponse:
        # stream 참여하기 위한 채팅방 생성
        stream_create = StreamCreate(
            name=story_request.text_overlay.text,
            type="story",
            creator_id=user_id,
        )
        created_stream: StreamRead =  await self.stream_service.create_stream(
            db, stream_create)

        await self.subscriber_service.subscribe(
            db,
            user_id=user_id,
            stream_id=created_stream.id
        )

        story_create_post: StoryPostCreate = StoryPostCreate(
            author_id=user_id,
            stream_id=created_stream.id,
            image_url=story_request.image_url,
            text_overlay=story_request.text_overlay,
        )

        created_story_post: StoryPostBase = await self.story_post_crud.create(
            db=db,
            story_post=story_create_post
        )

        return StoryPostResponse.model_validate(created_story_post)

    async def get_detail_story_post(self, db: AsyncSession, story_post_id: int,
                                    user_id: int) -> StoryPostResponse:
        story_post_base: StoryPostBase = await self.story_post_crud.get(db,
                                                                        story_post_id)

        subscribers = await self.subscriber_service.get_subscribers(db, story_post_base.stream_id)
        is_subscribed = user_id in subscribers

        return StoryPostResponse(
            id=story_post_base.id,
            author_id=story_post_base.author_id,
            text_overlay=story_post_base.text_overlay,
            image_url=story_post_base.image_url,
            is_subscribed=is_subscribed,
            created_at=story_post_base.created_at
        )

    async def list_story_post(
            self,
            db: AsyncSession,
            user_id: int,
            skip: int = 0,
            limit: int = 10) -> list[StoryPostResponse]:

        story_post_bases: list[StoryPostBase] = \
            await self.story_post_crud.list(db, skip=skip, limit=limit)

        responses = []
        for post in story_post_bases:
            # 각 스토리의 stream_id에 대한 구독자 목록 확인
            subscribers = await self.subscriber_service.get_subscribers(db,
                                                                        post.stream_id)
            is_subscribed = user_id in subscribers

            responses.append(
                StoryPostResponse(
                    id=post.id,
                    author_id=post.author_id,
                    text_overlay=post.text_overlay,
                    image_url=post.image_url,
                    is_subscribed=is_subscribed,
                    created_at=post.created_at
                )
            )

        return responses

    async def subscribe_to_story_post(
            self,
            db: AsyncSession,
            user_id: int,
            story_post_id: int
    ) -> bool:
        """
        story_post에 사용자를 구독시키는 로직:
        - 게시글 존재 확인
        - 이미 구독했을 시 에러
        """
        story_post: StoryPostBase = await self.story_post_crud.get(db,
                                                                   story_post_id)
        if story_post is None:
            raise ValueError("해당 스토리를 찾을 수 없습니다.")

        current_subscribers = await self.subscriber_service.get_subscribers(db,
                                                                            story_post.stream_id)
        if user_id in current_subscribers:
            raise ValueError("이미 참여한 사용자입니다.")

        await self.subscriber_service.subscribe(db, user_id,
                                                story_post.stream_id)
        return True


async def get_story_post_service(
    story_post_crud: StoryPostCRUD = Depends(get_story_post_crud),
    stream_service: StreamService = Depends(get_stream_service),
    subscriber_service: SubscriberService = Depends(get_subscription_service),
    s3_manager: S3Manager = Depends(get_s3_manager),
) -> StoryPostService :
    return StoryPostService(
        story_post_crud, stream_service, subscriber_service, s3_manager
    )