import uuid
from typing import Any, AsyncGenerator, Optional

from fastapi import Depends, HTTPException, Request, status
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
        self,
        user_db: SQLAlchemyUserDatabase,
        email_service: EmailServiceProtocol,
    ):
        super().__init__(user_db)
        self.email_service = email_service
        self.reset_password_token_secret = settings.SECRET_KEY
        # self.verification_token_secret = settings.SECRET_KEY

    def parse_id(self, id_value: Any) -> int:
        return super().parse_id(id_value)

    async def authenticate(
        self, credentials: OAuth2PasswordRequestForm
    ) -> Optional[models.UP]:
        user = await super().authenticate(credentials)
        if user and not user.is_verified:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="이메일 인증이 필요합니다. 이메일을 확인해주세요.",
            )
        return user

    async def create(
        self,
        user_create: schemas.UC,  # UC는 FastAPI Users에서 가져온 유저 생성 스키마
        safe: bool = False,
        request: Optional[Request] = None,
    ) -> User:
        if not self.email_service.validate_email_domain(user_create.email):
            raise ValueError("Invalid email domain.")
        return await super().create(user_create, safe, request)

    async def on_after_register(
        self, user: UP, request: Optional[Request] = None
    ) -> None:
        await self.email_service.send_email_verification_link(user)

    async def activate_user(self, user_id: int) -> None:
        user = await self.user_db.get(user_id)  # user 조회

        if user is None:
            raise ValueError(f"User with id {user_id} not found")

        if user.is_verified:
            raise ValueError("User already activated")

        update_dict = {"is_verified": True}
        await self.user_db.update(user, update_dict)

    # 사용자 정보 업데이트
    async def _update(self, user: User, user_update: dict) -> User:
        return await super()._update(user, user_update)

    # OAuth 인증이 성공적으로 완료된 후, 추가적인 로직을 수행하기 위해 오버라이딩
    async def oauth_callback(
        self,
        oauth_name: str,
        access_token: str,
        account_id: str,
        account_email: str,
        expires_at: Optional[int] = None,
        refresh_token: Optional[str] = None,
        request: Optional[Request] = None,
        *,
        associate_by_email: bool = False,
        is_verified_by_default: bool = False,
    ) -> dict:
        # OAuth 인증이 성공적으로 완료된 후, 기본 OAuth 로직을 수행합니다.
        user = await super().oauth_callback(
            oauth_name,
            access_token,
            account_id,
            account_email,
            expires_at,
            refresh_token,
        )
    
        #첫 로그인인 경우 추가 정보를 업데이트한후 반환
        if user.name == None and user.gender == None:
                update_dict = {
                    "is_verified": True,
                    "name": uuid.uuid4().hex,
                    "gender": "기타",
                }
                await self.user_db.update(user, update_dict)
                return {"user":user, "is_first_login":True}
        
        return {"user":user, "is_first_login":False}



async def get_user_manager(
    user_db: SQLAlchemyUserDatabase = Depends(get_user_db),
    email_service: EmailServiceProtocol = Depends(get_email_service),
) -> AsyncGenerator[UserManager, None]:
    yield UserManager(user_db, email_service)
