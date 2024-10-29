import unittest
from unittest import TestCase
from unittest.mock import AsyncMock, Mock, patch

from fastapi_users import BaseUserManager
from fastapi_users.authentication import JWTStrategy
from fastapi_users.models import UserProtocol

from app.core.config import settings
from app.service.email import EmailService, EmailVerificationService


class TestEmailService(TestCase):
    @patch("app.utils.email.send_email", new_callable=AsyncMock)
    def setUp(self, mock_send_email):
        self.template_render = Mock()
        self.verification_service = AsyncMock()
        self.email_service = EmailService(
            self.template_render, self.verification_service
        )
        self.mock_send_email = mock_send_email

    def test_validate_email_domain(self):
        valid_email = f"user{settings.UNIVERSITY_EMAIL_DOMAIN}"
        self.assertTrue(self.email_service.validate_email_domain(valid_email))

        invalid_email = "user@invalid.com"
        self.assertFalse(self.email_service.validate_email_domain(invalid_email))

    @patch("app.utils.email.send_email", new_callable=AsyncMock)
    async def test_send_email_verification_link(self, mock_send_email):
        user = Mock(spec=UserProtocol)
        user.email = f"user{settings.UNIVERSITY_EMAIL_DOMAIN}"

        token = "mocked_token"
        self.verification_service.create_verification_token.return_value = token

        rendered_content = "rendered email content"
        self.template_render.render_template.return_value = rendered_content

        await self.email_service.send_email_verification_link(user)

        # 이메일 템플릿 렌더링 확인
        self.template_render.render_template.assert_called_once_with(
            "new_register.html",
            verification_link=f"http://{settings.DOMAIN}:8000/api/v1/auth/verify-email?token={token}",
            user=user,
        )

        # 이메일 발송 확인
        mock_send_email.assert_awaited_once_with(
            user.email, "이메일 인증", rendered_content
        )


class TestEmailVerificationService(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.jwt_strategy = AsyncMock(spec=JWTStrategy)
        self.email_verification_service = EmailVerificationService(self.jwt_strategy)
        self.user_manager = AsyncMock(spec=BaseUserManager)

    async def test_create_verification_token(self):
        user = Mock(spec=UserProtocol)
        expected_token = "mocked_token"
        self.jwt_strategy.write_token.return_value = expected_token

        token = await self.email_verification_service.create_verification_token(user)

        self.assertEqual(token, expected_token)
        self.jwt_strategy.write_token.assert_awaited_once_with(user)

    async def test_verify_email_token_success(self):
        token = "valid_token"
        user = Mock(spec=UserProtocol)
        self.jwt_strategy.read_token.return_value = user

        result = await self.email_verification_service.verify_email_token(
            token, self.user_manager
        )

        self.assertEqual(result, user)
        self.jwt_strategy.read_token.assert_awaited_once_with(
            token, user_manager=self.user_manager
        )

    async def test_verify_email_token_invalid(self):
        token = "invalid_token"
        self.jwt_strategy.read_token.return_value = None

        with self.assertRaises(Exception) as context:
            await self.email_verification_service.verify_email_token(
                token, self.user_manager
            )

        self.assertEqual(str(context.exception), "Failed to verify email token: Invalid token")
        self.jwt_strategy.read_token.assert_awaited_once_with(
            token, user_manager=self.user_manager
        )
