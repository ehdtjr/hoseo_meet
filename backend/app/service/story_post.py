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

    async def get_detail_story_post(self, db: AsyncSession, story_post_id: int) \
        -> StoryPostResponse:
        story_post_base: StoryPostBase = (
            await self.story_post_crud.get(db, story_post_id)
        )
        return StoryPostResponse.model_validate(story_post_base)

    async def list_story_post(
        self,
        db: AsyncSession,
        skip: int = 0,
        limit: int = 10) -> list[StoryPostResponse]:
        story_post_bases: list[StoryPostBase] =\
            await self.story_post_crud.list(db, skip=skip, limit=limit)
        return [StoryPostResponse.model_validate(post) for post in story_post_bases]


async def get_story_post_service(
    story_post_crud: StoryPostCRUD = Depends(get_story_post_crud),
    stream_service: StreamService = Depends(get_stream_service),
    subscriber_service: SubscriberService = Depends(get_subscription_service),
    s3_manager: S3Manager = Depends(get_s3_manager),
) -> StoryPostService :
    return StoryPostService(
        story_post_crud, stream_service, subscriber_service, s3_manager
    )