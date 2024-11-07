from typing import Any, AsyncGenerator, Optional

from fastapi import (Depends, HTTPException, Request, status)
from fastapi.security import OAuth2PasswordRequestForm
from fastapi_users import BaseUserManager, IntegerIDMixin, models, schemas
from fastapi_users.db import SQLAlchemyUserDatabase
from fastapi_users.models import UP

from app.api.deps import get_user_db
from app.core.config import settings
from app.models.user import User
from app.service.email import EmailServiceProtocol, get_email_service


class UserManager(IntegerIDMixin, BaseUserManager[User, int]):

    def __init__(
            self, user_db: SQLAlchemyUserDatabase,
            email_service: EmailServiceProtocol
    ):
        super().__init__(user_db)
        self.email_service = email_service
        self.reset_password_token_secret = settings.SECRET_KEY

    def parse_id(self, id_value: Any) -> int:
        return super().parse_id(id_value)

    async def authenticate(
            self, credentials: OAuth2PasswordRequestForm
    ) -> Optional[models.UP]:
        user = await super().authenticate(credentials)
        if user and not user.is_verified:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="이메일 인증이 필요합니다. 이메일을 확인해주세요."
            )
        return user

    async def create(
            self,
            user_create: schemas.UC,  # UC는 FastAPI Users에서 가져온 유저 생성 스키마
            safe: bool = False,
            request: Optional[Request] = None,
    ) -> User:
        # if not self.email_service.validate_email_domain(user_create.email):
        #     raise ValueError("Invalid email domain.")
        return await super().create(user_create, safe, request)

    async def on_after_register(
            self, user: UP, request: Optional[Request] = None
    ) -> None:
        pass
        # await self.email_service.send_email_verification_link(user)

    async def activate_user(self, user_id: int) -> None:
        user = await self.user_db.get(user_id)  # user 조회

        if user is None:
            raise ValueError(f"User with id {user_id} not found")

        if user.is_verified:
            raise ValueError("User already activated")

        update_dict = {"is_verified": True}
        await self.user_db.update(user, update_dict)


async def get_user_manager(
        user_db: SQLAlchemyUserDatabase = Depends(get_user_db),
        email_service: EmailServiceProtocol = Depends(get_email_service),
) -> AsyncGenerator[UserManager, None]:
    yield UserManager(user_db, email_service)
