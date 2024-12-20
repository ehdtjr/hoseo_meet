from datetime import datetime
from unittest.mock import AsyncMock

from app.crud.meet_post_crud import MeetPostCRUDProtocol
from app.crud.user_crud import UserCRUDProtocol
from app.models import User
from app.schemas.meet_post import MeetPostBase
from app.schemas.user import UserRead
from app.service.meet_post import MeetPostService
from app.service.stream import StreamServiceProtocol, SubscriberServiceProtocol
from app.tests.conftest import BaseTest


class TestMeetPostService(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()

        self.stream_service = AsyncMock(spec=StreamServiceProtocol)
        self.meet_post_crud = AsyncMock(spec=MeetPostCRUDProtocol)
        self.subscriber_service = AsyncMock(spec=SubscriberServiceProtocol)
        self.user_crud = AsyncMock(spec=UserCRUDProtocol)
        self.service = MeetPostService(
            meet_post_crud=self.meet_post_crud,
            stream_service=self.stream_service,
            subscriber_service=self.subscriber_service,
            user_crud=self.user_crud
        )

        # 테스트에 필요한 사용자 데이터 생성
        user_data = {
            "email": "testuser@example.com",
            "hashed_password": "hashedpassword",
            "name": "Test User",
            "gender": "male",
            "is_active": True,
            "is_superuser": False,
            "is_verified": True,
        }

        # 사용자 생성
        user = User(**user_data)
        self.db.add(user)
        await self.db.commit()
        await self.db.refresh(user)
        self.user = UserRead.model_validate(user)


    async def test_subscribe_to_meet_post(self):
        # 테스트용 meet_post 데이터 설정
        meet_post_data = MeetPostBase(
            id=1,
            title="Test Meet Post",
            type="meet",
            author_id=self.user.id,
            stream_id=2,
            content="This is a test meet post",
            page_views=0,
            created_at=datetime.now(),
            max_people=5
        )

        # Mock 메서드의 반환값 설정
        self.meet_post_crud.get.return_value = meet_post_data
        self.subscriber_service.get_subscribers.return_value = [11, 12, 13, 14]


        # 테스트 대상 함수 실행
        result = await self.service.subscribe_to_meet_post(
            db=self.db, user_id=self.user.id, meet_post_id=meet_post_data.id
        )

        # 결과 검증
        self.assertTrue(result)  # 구독 성공 여부 확인
        self.meet_post_crud.get.assert_called_once_with(self.db, meet_post_data.id)
        self.subscriber_service.get_subscribers.assert_called_once_with(self.db, 2)
        self.subscriber_service.subscribe.assert_called_once_with(self.db, self.user.id, 2)

    async def test_subscribe_to_meet_post_not_found(self):
        # meet_post_crud.get이 None을 반환하도록 설정
        self.meet_post_crud.get.return_value = None

        # ValueError 발생 여부 확인
        with self.assertRaises(ValueError) as context:
            await self.service.subscribe_to_meet_post(
                db=self.db, user_id=self.user.id, meet_post_id=1
            )

        # 예외 메시지가 올바른지 확인
        self.assertEqual(str(context.exception), "해당 게시글을 찾을 수 없습니다.")


    async def test_subscribe_to_meet_post_already_subscribed(self):
        stream_id = 2
        meet_post_data = MeetPostBase(
            id=1,
            title="Test Meet Post",
            type="meet",
            author_id=self.user.id,
            stream_id=stream_id,
            content="This is a test meet post",
            page_views=0,
            created_at=datetime.now(),
            max_people=5
        )

        # Mock 메서드의 반환값 설정
        self.meet_post_crud.get.return_value = meet_post_data
        # 구독자 목록에 self.user.id 포함
        self.subscriber_service.get_subscribers.return_value = [1, self.user.id, 3, 4]

        with self.assertRaises(ValueError) as context:
            await self.service.subscribe_to_meet_post(
                db=self.db, user_id=self.user.id, meet_post_id=meet_post_data.id
            )

        # 예외 메시지가 올바른지 확인
        self.assertEqual(str(context.exception), "이미 참가한 사용자입니다.")


    async def test_subscribe_to_meet_post_exceeds_capacity(self):
        # meet_post 데이터 설정
        meet_post_data = MeetPostBase(
            id=1,
            title="Test Meet Post",
            type="meet",
            author_id=self.user.id,
            stream_id=2,
            content="This is a test meet post",
            page_views=0,
            created_at=datetime.now(),
            max_people=5  # 최대 인원을 5명으로 설정
        )

        # meet_post_crud.get이 meet_post_data를 반환하도록 설정
        self.meet_post_crud.get.return_value = meet_post_data

        # 이미 구독자 수가 최대 인원에 도달한 상태로 설정
        self.subscriber_service.get_subscribers.return_value = [1, 2, 3, 4, 5]

        # ValueError 발생 여부 확인
        with self.assertRaises(ValueError) as context:
            await self.service.subscribe_to_meet_post(
                db=self.db, user_id=self.user.id,
                meet_post_id=meet_post_data.id
            )

        # 예외 메시지가 올바른지 확인
        self.assertEqual(str(context.exception), "참가 가능한 인원을 초과했습니다.")
