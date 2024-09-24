import uuid
from typing import Optional, AsyncGenerator

from fastapi import Depends, Request
from fastapi_users import UUIDIDMixin, BaseUserManager, schemas
from fastapi_users.db import SQLAlchemyUserDatabase
from fastapi_users.models import UP

from app.api.deps import get_user_db
from app.core.config import settings
from app.models.user import User
from app.service.email import EmailServiceProtocol, get_email_service


class UserManager(UUIDIDMixin, BaseUserManager[User, uuid.UUID]):
    def __init__(
        self, user_db: SQLAlchemyUserDatabase, email_service: EmailServiceProtocol
    ):
        super().__init__(user_db)
        self.email_service = email_service
        self.reset_password_token_secret = settings.SECRET_KEY

    async def create(
        self,
        user_create: schemas.UC,
        safe: bool = False,
        request: Optional[Request] = None,
    ) -> User:  # 여기서 User로 변경
        if not self.email_service.validate_email_domain(user_create.email):
            raise ValueError("Invalid email domain.")
        return await super().create(user_create, safe, request)  # type: ignore

    async def on_after_register(
        self, user: UP, request: Optional[Request] = None
    ) -> None:
        await self.email_service.send_email_verification_link(user)

    async def activate_user(self, user: User) -> None:
        if user.is_verified:
            raise ValueError("User already activated")
        update_dict = {"is_verified": True}
        await self.user_db.update(user, update_dict)


async def get_user_manager(
    user_db: SQLAlchemyUserDatabase = Depends(get_user_db),
    email_service: EmailServiceProtocol = Depends(get_email_service),
) -> AsyncGenerator[UserManager, None]:
    yield UserManager(user_db, email_service)
