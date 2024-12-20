from unittest import TestCase

from httpx import ASGITransport, AsyncClient
from unittest.mock import AsyncMock
from app.core.db import get_async_session
from app.core.security import current_active_user
from app.main import app
from app.schemas.meet_post import MeetPostBase, MeetPostListResponse
from app.schemas.user import UserPublicRead
from app.service.meet_post import MeetPostServiceProtocol, \
    get_meet_post_service
from app.tests.conftest import BaseTest, override_get_db


class TestMeetPostRoutes(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()
        # 테스트 사용자 생성
        user_data = {
            "email": "testuser@example.com",
            "hashed_password": "hashedpassword",
            "name": "Test User",
            "gender": "male",
            "is_active": True,
            "is_superuser": False,
            "is_verified": True,
        }
        from app.models import User
        self.user = User(**user_data)
        self.db.add(self.user)
        await self.db.commit()
        await self.db.refresh(self.user)
        self.user_id = self.user.id

    async def asyncTearDown(self):
        await super().asyncTearDown()

    def get_mock_meet_post_service(self):
        mock_meet_post_service = AsyncMock(spec=MeetPostServiceProtocol)
        return mock_meet_post_service

    async def override_get_current_user(self):
        return self.user

    async def test_create_meet(self):
        mock_meet_post_service = self.get_mock_meet_post_service()

        # 가짜 응답 생성
        from datetime import datetime
        mock_meet_post_service.create_meet_post.return_value = MeetPostBase(
            id=1,  # 필수 필드 추가
            created_at=datetime.utcnow(),  # 필수 필드 추가
            title="Test Meet",
            author_id=self.user.id,
            stream_id=1,
            type="meet",
            content="This is a test meet post.",
            max_people=5,
        )

        # 요청 데이터
        request_data = {
            "title": "Test Meet",
            "type": "meet",
            "content": "This is a test meet post.",
            "max_people": 5
        }

        # HTTP 클라이언트로 테스트 API 호출
        async with AsyncClient(transport=ASGITransport(app=app),
                               base_url="http://test") as ac:
            # 의존성 주입 설정
            app.dependency_overrides[
                current_active_user] = self.override_get_current_user
            app.dependency_overrides[get_async_session] = override_get_db
            app.dependency_overrides[
                get_meet_post_service] = lambda: mock_meet_post_service

            # POST 요청 보내기
            response = await ac.post("/api/v1/meet_post/create",
                                     json=request_data)

        # 응답 검증
        assert response.status_code == 200
        response_data = response.json()
        assert response_data["title"] == "Test Meet"
        assert response_data["author_id"] == self.user.id
        assert response_data["type"] == "meet"
        assert response_data["content"] == "This is a test meet post."
        assert response_data["max_people"] == 5

        # 서비스 호출 검증
        mock_meet_post_service.create_meet_post.assert_called_once()

    async def test_get_filtered_meet_posts(self):
        # Mock meet_post_service 생성
        mock_meet_post_service = self.get_mock_meet_post_service()

        from datetime import datetime
        mock_meet_post_service.get_filtered_meet_posts.return_value = [
            MeetPostListResponse(
                id=1,
                created_at=datetime.utcnow(),
                title="Test Meet 1",
                author=UserPublicRead.model_validate(self.user),
                stream_id=1,
                type="meet",
                content="Content for test meet 1",
                max_people=3,
                current_people=2
            ),
            MeetPostListResponse(
                id=2,
                created_at=datetime.utcnow(),
                title="Test Meet 2",
                author=UserPublicRead.model_validate(self.user),
                stream_id=2,
                type="taxi",
                content="Content for test meet 2",
                max_people=4,
                current_people=1
            )
        ]

        async with AsyncClient(transport=ASGITransport(app=app),
                               base_url="http://test") as ac:
            app.dependency_overrides[
                current_active_user] = self.override_get_current_user
            app.dependency_overrides[get_async_session] = override_get_db
            app.dependency_overrides[
                get_meet_post_service] = lambda: mock_meet_post_service

            response = await ac.get("/api/v1/meet_post/search",
                                    params={"title": "Test Meet"})

        assert response.status_code == 200
        response_data = response.json()
        assert len(response_data) == 2  # 두 개의 Mock 게시물 반환 예상

        # 각 필드의 값을 검증 (딕셔너리 접근 수정)
        assert response_data[0]["title"] == "Test Meet 1"
        assert response_data[0]["author"]["id"] == self.user.id
        assert response_data[0]["type"] == "meet"
        assert response_data[0]["content"] == "Content for test meet 1"
        assert response_data[0]["max_people"] == 3
        assert response_data[0]["current_people"] == 2

        assert response_data[1]["title"] == "Test Meet 2"
        assert response_data[1]["author"]["id"] == self.user.id
        assert response_data[1]["type"] == "taxi"
        assert response_data[1]["content"] == "Content for test meet 2"
        assert response_data[1]["max_people"] == 4
        assert response_data[1]["current_people"] == 1

        mock_meet_post_service.get_filtered_meet_posts.assert_called_once()

    async def test_subscribe_to_meet_post(self):
        # Mock meet_post_service 생성
        mock_meet_post_service = self.get_mock_meet_post_service()

        # 구독 성공 시 반환될 값 설정
        mock_meet_post_service.subscribe_to_meet_post.return_value = True

        # 요청할 meet_post_id 설정
        meet_post_id = 1

        # HTTP 클라이언트로 테스트 API 호출
        async with AsyncClient(transport=ASGITransport(app=app),
                               base_url="http://test") as ac:
            # 의존성 주입 설정
            app.dependency_overrides[current_active_user] = self.override_get_current_user
            app.dependency_overrides[get_async_session] = override_get_db
            app.dependency_overrides[get_meet_post_service] = lambda: mock_meet_post_service

            # POST 요청 보내기 (구독 요청)
            response = await ac.post(f"/api/v1/meet_post/subscribe/{meet_post_id}")

        # 응답 검증
        assert response.status_code == 200
        response_data = response.json()
        assert response_data["success"] is True  # 구독이 성공했는지 확인
