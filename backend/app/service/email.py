from typing import Protocol
from fastapi import Depends
from fastapi_users import models, BaseUserManager
from fastapi_users.authentication import JWTStrategy
from fastapi_users.models import UserProtocol
from jinja2 import FileSystemLoader, Environment, select_autoescape

from app.core.config import settings
from app.utils.email import send_email


class EmailServiceProtocol(Protocol):
    async def send_email_verification_link(self, user: models.UP) -> None:
        pass

    def validate_email_domain(self, email: str) -> bool:
        pass


class EmailService(EmailServiceProtocol):
    email_domain = settings.UNIVERSITY_EMAIL_DOMAIN
    send_email_domain = f"{settings.DOMAIN}:8000"

    def __init__(
        self,
        template_renderer: "EmailTemplateRender",
        verification_service: "EmailVerificationService",
    ):
        self.template_renderer = template_renderer
        self.verification_service = verification_service

    def validate_email_domain(self, email: str) -> bool:
        return email.endswith(self.email_domain)

    async def send_email_verification_link(self, user: models.UP) -> None:
        # 인증 토큰 생성
        token = await self.verification_service.create_verification_token(user)
        verification_link = (
            f"http://{self.send_email_domain}/api/v1/auth/verify-email?token"
            f"={token}"
        )
        # 이메일 템플릿 렌더링
        content = self.template_renderer.render_template(
            "new_register.html", verification_link=verification_link, user=user
        )

        # 이메일 발송
        await send_email(user.email, "이메일 인증", content)


# 이메일 인증 서비스 클래스
class EmailVerificationService:
    def __init__(self, jwt_strategy: JWTStrategy):
        self.jwt_strategy = jwt_strategy

    async def create_verification_token(self, user: UserProtocol) -> str:
        return await self.jwt_strategy.write_token(user)

    async def verify_email_token(
        self, token: str, user_manager: BaseUserManager[models.UP, models.ID]
    ) -> UserProtocol:
        user = await self.jwt_strategy.read_token(token, user_manager=user_manager)
        if not user:
            raise Exception("Invalid token")
        return user


# 이메일 템플릿 렌더링 클래스
class EmailTemplateRender:
    template_dir = settings.EMAIL_TEMPLATE_DIR.resolve()

    def __init__(self):
        self.template_env = Environment(
            loader=FileSystemLoader(self.template_dir),
            autoescape=select_autoescape(["html", "xml"]),
        )

    def render_template(self, template_name: str, **context) -> str:
        template = self.template_env.get_template(template_name)
        return template.render(**context)


def get_email_jwt_strategy() -> JWTStrategy:
    return JWTStrategy(secret=settings.SECRET_KEY, lifetime_seconds=600)


def get_email_verification_service(
    jwt_strategy: JWTStrategy = Depends(get_email_jwt_strategy),
) -> EmailVerificationService:
    return EmailVerificationService(jwt_strategy)


def get_email_template_render() -> EmailTemplateRender:
    return EmailTemplateRender()


def get_email_service(
    template_renderer: EmailTemplateRender = Depends(get_email_template_render),
    verification_service: EmailVerificationService = Depends(
        get_email_verification_service
    ),
) -> EmailServiceProtocol:
    return EmailService(template_renderer, verification_service)
