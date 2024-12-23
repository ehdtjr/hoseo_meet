from app.service.auth import CustomJWTStrategy, RedisTokenStorage
from fastapi import APIRouter, Depends, HTTPException, status, Header
from app.core.security import (
    auth_backend,
    get_custom_jwt_strategy,
    get_redis_token_storage,
)
from app.service.email import EmailVerificationService, get_email_verification_service
from app.schemas.user import UserRead, UserCreate, UserUpdate
from app.core.security import fastapi_users
from app.service.user import UserManager, get_user_manager
from typing import Optional
from app.schemas.user import UserUpdate
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import APIKeyHeader, OAuth2PasswordRequestForm
from app.schemas.auth import Token
from fastapi_users.manager import BaseUserManager
from fastapi_users import models
from fastapi_users.router.common import ErrorCode
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi_users.jwt import decode_jwt
from app.core.config import settings
from app.core.redis import redis_client
import jwt

router = APIRouter()

# Access Token을 위한 헤더
access_token_header = APIKeyHeader(name="access_token", auto_error=False)

# Refresh Token을 위한 커스텀 헤더
refresh_token_header = APIKeyHeader(name="refresh_token", auto_error=False)


# 이메일 인증
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


# 로그인
@router.post("/login", tags=["auth"])
async def login(
    credentials: OAuth2PasswordRequestForm = Depends(),
    user_manager: BaseUserManager[models.UP, models.ID] = Depends(get_user_manager),
    jwt_strategy: CustomJWTStrategy = Depends(get_custom_jwt_strategy),
):

    user = await user_manager.authenticate(credentials)

    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=ErrorCode.LOGIN_BAD_CREDENTIALS,
        )

    # access_token, refresh_token 생성
    tokens = await jwt_strategy.write_token(user)

    return {
        "message": "login successful",
        "access_token": tokens["access_token"],
        "refresh_token": tokens["refresh_token"],
    }


# 로그아웃
@router.post("/logout", tags=["auth"])
async def logout(
    access_token: str = Depends(access_token_header),
    refresh_token: str = Depends(refresh_token_header),
    redis_storage: RedisTokenStorage = Depends(get_redis_token_storage),
    jwt_strategy: CustomJWTStrategy = Depends(get_custom_jwt_strategy),
):
    try:
        # Access Token 검증 (유효성 체크만)
        access_token = access_token.split(" ")[1]
        await jwt_strategy.decode_token(access_token)

        # Refresh Token 검증 및 사용자 ID 추출
        refresh_token = refresh_token.split(" ")[1]
        user_id = await jwt_strategy.validate_refresh_token(refresh_token)

        # Redis에서 Refresh Token 삭제
        await redis_storage.delete_token(user_id)

        return {"message": "Logout successful"}
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An unexpected error occurred",
        )


# Access Token, Refresh Token 갱신
@router.post("/refresh", tags=["auth"])
async def refresh_token(
    refresh_token: str = Depends(refresh_token_header),
    user_manager: BaseUserManager[models.UP, models.ID] = Depends(get_user_manager),
    jwt_strategy: CustomJWTStrategy = Depends(get_custom_jwt_strategy),
):
    try:
        refresh_token = refresh_token.split(" ")[1]
        user_id = await jwt_strategy.validate_refresh_token(refresh_token)

        user = await user_manager.get(int(user_id))
        if user is None or not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or inactive user",
            )

        tokens = await jwt_strategy.write_token(user)  # 실제 사용자 모델에 맞게 조정
        return tokens

    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


# JWT 토큰 디코딩 테스트용
@router.get("/decode", tags=["auth"])
async def decode_jwt_token(
    authorization: Optional[str] = Depends(
        access_token_header
    ),  # Authorization 헤더에서 JWT 토큰 추출
):

    token = authorization.split(" ")[1]

    try:
        # JWT 디코딩
        payload = decode_jwt(
            token,
            secret=settings.SECRET_KEY,
            audience=["fastapi-users:auth"],
            algorithms=["HS256"],
        )
        return {"message": "Token decoded successfully", "payload": payload}

    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Token has expired"
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token"
        )


# 인증 및 사용자 관련 라우터 추가
router.include_router(
    fastapi_users.get_register_router(UserRead, UserCreate), tags=["auth"]
)
router.include_router(fastapi_users.get_reset_password_router(), tags=["auth"])
router.include_router(fastapi_users.get_verify_router(UserRead), tags=["auth"])
router.include_router(
    fastapi_users.get_users_router(UserRead, UserUpdate), tags=["auth"]
)
