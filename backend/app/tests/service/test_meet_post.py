from datetime import datetime
from unittest.mock import AsyncMock

from app.crud.meet_post_crud import MeetPostCRUDProtocol
from app.crud.user import UserCRUDProtocol
from app.models import User
from app.schemas.meet_post import MeetPostBase, MeetPostResponse
from app.schemas.user import UserRead
from app.service.meet_post import MeetPostService, ViewCountService
from app.service.stream import StreamServiceProtocol, SubscriberServiceProtocol
from app.tests.conftest import BaseTest


class TestMeetPostService(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()

        self.stream_service = AsyncMock(spec=StreamServiceProtocol)
        self.meet_post_crud = AsyncMock(spec=MeetPostCRUDProtocol)
        self.subscriber_service = AsyncMock(spec=SubscriberServiceProtocol)
        self.user_crud = AsyncMock(spec=UserCRUDProtocol)
        self.view_count_service = AsyncMock()

        self.service = MeetPostService(
            meet_post_crud=self.meet_post_crud,
            stream_service=self.stream_service,
            subscriber_service=self.subscriber_service,
            user_crud=self.user_crud,
            view_count_service=self.view_count_service
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
        self.meet_post_crud.get.assert_called_once_with(self.db,
                                                        meet_post_data.id)
        self.subscriber_service.get_subscribers.assert_called_once_with(self.db,
                                                                        2)
        self.subscriber_service.subscribe.assert_called_once_with(self.db,
                                                                  self.user.id,
                                                                  2)

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
        self.subscriber_service.get_subscribers.return_value = [1, self.user.id,
                                                                3, 4]

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

    async def test_get_detail_meet_post_not_found(self):
        """
        meet_post가 존재하지 않는 경우 None 반환을 확인
        """
        meet_post_id = 999
        ip_address = "127.0.0.1"

        # meet_post_crud.get이 None 반환
        self.meet_post_crud.get.return_value = None

        result = await self.service.get_detail_meet_post(
            db=self.db,
            meet_post_id=meet_post_id,
            ip_address=ip_address
        )

        # result None 확인
        self.assertIsNone(result)
        # 조회수 증가 시도가 있었는지 확인
        self.view_count_service.increase_view_count.assert_awaited_once_with(self.db, meet_post_id, ip_address)

    async def test_get_detail_meet_post_found(self):
        """
        meet_post가 존재하는 경우 MeetPostResponse 반환 확인
        """
        meet_post_id = 1
        ip_address = "127.0.0.1"
        stream_id = 2
        author_id = self.user.id

        meet_post_data = MeetPostBase(
            id=meet_post_id,
            title="Test Post",
            type="meet",
            author_id=author_id,
            stream_id=stream_id,
            content="Some content",
            page_views=100,
            created_at=datetime.now(),
            max_people=5
        )

        # Mock 반환값 설정
        self.meet_post_crud.get.return_value = meet_post_data

        # 작성자 정보 설정
        self.user_crud.get.return_value = self.user

        # 구독자 목록 설정
        subscribers = [3,4]
        self.subscriber_service.get_subscribers.return_value = subscribers

        result = await self.service.get_detail_meet_post(
            db=self.db,
            meet_post_id=meet_post_id,
            ip_address=ip_address
        )

        # increase_view_count 호출 확인
        self.view_count_service.increase_view_count.assert_awaited_once_with(self.db, meet_post_id, ip_address)

        # meet_post_crud.get 호출 확인
        self.meet_post_crud.get.assert_awaited_once_with(self.db, meet_post_id)

        # user_crud.get 호출 확인
        self.user_crud.get.assert_awaited_once_with(self.db, author_id)

        # subscriber_service.get_subscribers 호출 확인
        self.subscriber_service.get_subscribers.assert_awaited_once_with(self.db, stream_id)

        # 반환값 검증
        self.assertIsInstance(result, MeetPostResponse)
        self.assertEqual(result.id, meet_post_data.id)
        self.assertEqual(result.title, meet_post_data.title)
        self.assertEqual(result.type, meet_post_data.type)
        self.assertEqual(result.author.id, self.user.id)
        self.assertEqual(result.author.name, self.user.name)
        self.assertEqual(result.stream_id, meet_post_data.stream_id)
        self.assertEqual(result.content, meet_post_data.content)
        self.assertEqual(result.page_views, meet_post_data.page_views)
        self.assertEqual(result.max_people, meet_post_data.max_people)
        self.assertEqual(result.current_people, len(subscribers))


class TestViewCountService(BaseTest):

    async def asyncSetUp(self):
        await super().asyncSetUp()
        self.meet_post_crud = AsyncMock(spec=MeetPostCRUDProtocol)
        self.view_count_service = ViewCountService(
            meet_post_crud=self.meet_post_crud)
        # BaseTest에서 redis_client를 제공한다고 가정
        await self.redis_client.flushdb()  # Redis 초기화

    async def test_increase_view_count_first_time(self):
        """
        처음 특정 (meet_post_id, ip_address) 조합으로 조회할 때,
        조회수가 정상적으로 1 증가하고 Redis에 해당 키가 저장되는지 확인.
        """
        meet_post_id = 1
        ip_address = "127.0.0.1"
        # 테스트용 MeetPostBase 객체
        meet_post_data = MeetPostBase(
            id=meet_post_id,
            title="Test Post",
            type="meet",
            author_id=1,
            stream_id=10,
            content="Test Content",
            page_views=0,
            created_at=datetime.now(),
            max_people=10
        )

        self.meet_post_crud.get.return_value = meet_post_data

        await self.view_count_service.increase_view_count(self.db, meet_post_id,
                                                          ip_address)

        # update가 호출되었는지 확인
        self.meet_post_crud.update.assert_awaited_once()
        updated_post = self.meet_post_crud.update.call_args[0][
            1]  # 첫 번째 인자가 db, 두 번째가 meet_post
        self.assertEqual(updated_post.page_views, 1)  # 조회수 1 증가 확인

        # Redis에 key 존재 여부 확인
        key = f"meet_post_view:{meet_post_id}:{ip_address}"
        exists = await self.redis_client.exists(key)
        self.assertEqual(exists, 1)  # 키가 존재해야 함

    async def test_increase_view_count_second_time_same_ip(self):
        """
        같은 meet_post_id, 같은 ip_address로 두 번째 조회 시도시,
        조회수가 증가하지 않는지 확인.
        """
        meet_post_id = 1
        ip_address = "127.0.0.1"

        meet_post_data = MeetPostBase(
            id=meet_post_id,
            title="Another Test Post",
            type="meet",
            author_id=1,
            stream_id=11,
            content="Another Test Content",
            page_views=0,
            created_at=datetime.now(),
            max_people=10
        )

        self.meet_post_crud.get.return_value = meet_post_data

        # 첫 번째 조회 (증가 발생)
        await self.view_count_service.increase_view_count(self.db, meet_post_id,
                                                          ip_address)
        self.meet_post_crud.update.assert_awaited_once()

        # update 호출 횟수 초기화
        self.meet_post_crud.update.reset_mock()

        # 두 번째 조회 (증가 없음)
        await self.view_count_service.increase_view_count(self.db, meet_post_id,
                                                          ip_address)
        self.meet_post_crud.update.assert_not_awaited()

        # Redis 키는 이미 존재하기 때문에 조회수 증가 없음
        key = f"meet_post_view:{meet_post_id}:{ip_address}"
        exists = await self.redis_client.exists(key)
        self.assertEqual(exists, 1)  # 여전히 키가 존재

    async def test_increase_view_count_different_ip(self):
        """
        같은 meet_post_id지만 다른 ip_address로 조회 시도 시,
        각각에 대해 첫 조회는 조회수가 증가하는지 확인.
        """
        meet_post_id = 2
        ip_address_1 = "192.168.0.1"
        ip_address_2 = "10.0.0.1"

        meet_post_data = MeetPostBase(
            id=meet_post_id,
            title="Test Post Diff IP",
            type="meet",
            author_id=2,
            stream_id=12,
            content="Content for diff IP test",
            page_views=0,
            created_at=datetime.now(),
            max_people=10
        )

        self.meet_post_crud.get.return_value = meet_post_data

        # 첫 번째 IP 조회
        await self.view_count_service.increase_view_count(self.db, meet_post_id,
                                                          ip_address_1)
        self.meet_post_crud.update.assert_awaited_once()
        updated_post_1 = self.meet_post_crud.update.call_args[0][1]
        self.assertEqual(updated_post_1.page_views, 1)

        key_1 = f"meet_post_view:{meet_post_id}:{ip_address_1}"
        exists_1 = await self.redis_client.exists(key_1)
        self.assertEqual(exists_1, 1)

        # 두 번째 IP 조회 (다른 IP)
        self.meet_post_crud.update.reset_mock()
        await self.view_count_service.increase_view_count(self.db, meet_post_id,
                                                          ip_address_2)
        self.meet_post_crud.update.assert_awaited_once()
        updated_post_2 = self.meet_post_crud.update.call_args[0][1]
        self.assertEqual(updated_post_2.page_views, 2)  # 다시 증가해야 함

        key_2 = f"meet_post_view:{meet_post_id}:{ip_address_2}"
        exists_2 = await self.redis_client.exists(key_2)
        self.assertEqual(exists_2, 1)  # 다른 IP로 인한 키도 존재
