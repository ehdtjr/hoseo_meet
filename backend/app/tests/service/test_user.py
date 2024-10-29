from unittest.mock import AsyncMock, patch

from fastapi import HTTPException

from app.models.user import User
from app.service.user import UserManager
from app.tests.conftest import BaseTest


class TestUserManager(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()
        # Mock 객체 생성
        self.user_db = AsyncMock()
        self.email_service = AsyncMock()

        # UserManager 인스턴스 생성
        self.user_manager = UserManager(user_db=self.user_db,
                                        email_service=self.email_service)
    @patch("fastapi_users.password.PasswordHelper.verify_and_update", return_value=(True, None))
    async def test_authenticate_email_not_verified(self, mock_verify_and_update):
        user_data = {
            "email": "testuser@example.com",
            "hashed_password": "fakehashedpassword",  # 해싱된 비밀번호 사용
            "name": "Test User",
            "gender": "male",
            "is_active": True,
            "is_superuser": False,
            "is_verified": False,  # 이메일 인증되지 않음
        }

        # 사용자 생성
        user = User(**user_data)

        # OAuth2PasswordRequestForm 대신 credentials을 모의 설정
        credentials = AsyncMock()
        credentials.username = "testuser@example.com"
        credentials.password = "password"

        # user_db의 get_by_email 메서드가 이 사용자 객체를 반환하도록 설정 (비동기 모의 설정)
        self.user_manager.user_db.get_by_email = AsyncMock(return_value=user)

        # 이메일 인증되지 않은 사용자 로그인 시도
        with self.assertRaises(HTTPException) as context:
            await self.user_manager.authenticate(credentials)

        # 예외 메시지 확인
        self.assertEqual(context.exception.status_code, 403)
        self.assertEqual(context.exception.detail, "이메일 인증이 필요합니다. 이메일을 확인해주세요.")