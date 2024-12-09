from fastapi import APIRouter, Depends, HTTPException, status, Header

from app.core.security import auth_backend
from app.service.email import EmailVerificationService, get_email_verification_service
from app.schemas.user import UserRead, UserCreate, UserUpdate
from app.core.security import fastapi_users
from app.service.user import UserManager, get_user_manager
from typing import Optional
from app.schemas.user import UserUpdate
from app.models.user import User, OAuthAccount  # User 모델 import 필요
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import APIKeyHeader, OAuth2PasswordRequestForm
from app.schemas.auth import Token
from app.service.auth import generate_tokens, verify_token
from fastapi_users.manager import BaseUserManager
from fastapi_users import models
from fastapi_users.router.common import ErrorCode
from fastapi import APIRouter, Depends, HTTPException, Request, status

router = APIRouter()

api_key_header = APIKeyHeader(name="Authorization", auto_error=False)

@router.get("/verify-email", tags=["auth"])
async def verify_email(
    token: str,
    user_manager: UserManager = Depends(get_user_manager),
    email_verification_service: EmailVerificationService = Depends(
        get_email_verification_service
    ),
):
    try:
        user = await email_verification_service.verify_email_token(token, user_manager)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired token."
        )

    # Pydantic 모델로 명시적 캐스팅
    user_data = UserRead.model_validate(user)
    await user_manager.activate_user(user_data.id)
    return {"message": "Email verified successfully", "user": user_data}


# 인증 및 사용자 관련 라우터 추가
router.include_router(
    fastapi_users.get_auth_router(auth_backend), prefix="/jwt", tags=["auth"]
)

@router.post("/login", response_model=Token)
async def login(
    credentials: OAuth2PasswordRequestForm = Depends(),
    user_manager: BaseUserManager[models.UP, models.ID] = Depends(get_user_manager),
    ):
    
    user = await user_manager.authenticate(credentials)

    if user is None or not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=ErrorCode.LOGIN_BAD_CREDENTIALS,
            )

    tokens = await generate_tokens(user)
    return tokens

@router.post("/refresh", response_model=Token)
async def refresh_token(
    authorization: str = Depends(api_key_header),
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing refresh token",
        )
    refresh_token = authorization.split(" ")[1]
    user_id = await verify_token(refresh_token, token_type="refresh")
    # 사용자 유효성 검사
    tokens = await generate_tokens(user_id)
    return tokens

router.include_router(
    fastapi_users.get_register_router(UserRead, UserCreate), tags=["auth"]
)
router.include_router(fastapi_users.get_reset_password_router(), tags=["auth"])
router.include_router(fastapi_users.get_verify_router(UserRead), tags=["auth"])
router.include_router(
    fastapi_users.get_users_router(UserRead, UserUpdate), tags=["auth"]
)