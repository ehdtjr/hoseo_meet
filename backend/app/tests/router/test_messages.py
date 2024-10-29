from unittest.mock import AsyncMock

from httpx import ASGITransport, AsyncClient

from app.core.db import get_async_session
from app.core.exceptions import PermissionDeniedException
from app.core.security import current_active_user
from app.main import app
from app.service.message import MessageServiceProtocol, get_message_service
from app.tests.conftest import BaseTest, override_get_db


class TestSendMessageToStream(BaseTest):

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

    async def override_current_user(self):
        return self.user  #

    # Mock 객체를 명시적으로 설정하는 함수
    def get_mock_message_service(self):
        # MessageService 모의 객체 생성
        mock_message_service = AsyncMock(spec=MessageServiceProtocol)

        mock_message_service.send_message_stream = AsyncMock(return_value=None)
        return mock_message_service

    async def test_send_message_to_stream(self):
        # Mock 서비스 인스턴스를 호출
        mock_message_service = self.get_mock_message_service()

        # 정상적인 메시지 전송을 테스트
        async with AsyncClient(
                transport=ASGITransport(app=app), base_url="http://test"
        ) as ac:
            app.dependency_overrides[
                current_active_user] = self.override_current_user
            app.dependency_overrides[get_async_session] = override_get_db
            app.dependency_overrides[
                get_message_service] = lambda: mock_message_service

            stream_id = 1
            message_content = "Hello, Stream!"

            # 성공적인 요청: Form 데이터를 전송
            response = await ac.post(
                f"/api/v1/messages/send/stream/{stream_id}",
                data={"message_content": message_content},  # Form 데이터로 전송
            )

            # 응답 상태 및 메시지 확인
            assert response.status_code == 200
            assert response.json() == {"message": "Message sent successfully"}

    async def test_send_message_to_stream_permission_denied(self):
        mock_message_service = self.get_mock_message_service()

        # 권한이 없을 때의 예외 처리 설정
        mock_message_service.send_message_stream.side_effect = (
            PermissionDeniedException)

        async with AsyncClient(
                transport=ASGITransport(app=app), base_url="http://test"
        ) as ac:
            app.dependency_overrides[
                current_active_user] = self.override_current_user
            app.dependency_overrides[get_async_session] = override_get_db
            app.dependency_overrides[
                get_message_service] = lambda: mock_message_service

            stream_id = 1
            message_content = "Hello, Stream!"

            # 권한 없는 사용자가 메시지를 전송하려고 시도
            response = await ac.post(
                f"/api/v1/messages/send/stream/{stream_id}",
                data={"message_content": message_content},
            )

            # 403 Forbidden 응답 확인
            assert response.status_code == 403
            assert response.json() == {
                "detail": "You are not allowed to send messages to this stream"
            }

    async def test_send_message_to_stream_general_exception(self):
        mock_message_service = self.get_mock_message_service()

        # 일반 예외 발생 시 시나리오 설정
        mock_message_service.send_message_stream.side_effect = Exception(
            "Unknown error")

        async with AsyncClient(
                transport=ASGITransport(app=app), base_url="http://test"
        ) as ac:
            app.dependency_overrides[
                current_active_user] = self.override_current_user
            app.dependency_overrides[get_async_session] = override_get_db
            app.dependency_overrides[
                get_message_service] = lambda: mock_message_service

            stream_id = 1
            message_content = "Hello, Stream!"

            # 예외가 발생하는 요청 테스트
            response = await ac.post(
                f"/api/v1/messages/send/stream/{stream_id}",
                data={"message_content": message_content},
            )

            # 400 Bad Request 응답 확인
            assert response.status_code == 400
            assert "Message sending failed" in response.json()["detail"]
