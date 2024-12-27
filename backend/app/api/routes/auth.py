from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from fastapi_users import models
from fastapi_users.manager import BaseUserManager
from fastapi_users.router.common import ErrorCode

from app.core.security import fastapi_users
from app.core.security import (
    get_custom_jwt_strategy,
    get_redis_token_storage,
)
from app.schemas.user import UserRead, UserCreate, RefreshTokenRequest
from app.schemas.user import UserUpdate
from app.service.auth import CustomJWTStrategy, RedisTokenStorage
from app.service.email import EmailVerificationService, \
    get_email_verification_service
from app.service.user import UserManager, get_user_manager

router = APIRouter()



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
    data: RefreshTokenRequest,
    redis_storage: RedisTokenStorage = Depends(get_redis_token_storage),
    jwt_strategy: CustomJWTStrategy = Depends(get_custom_jwt_strategy),
):
    try:
        user_id = await jwt_strategy.validate_refresh_token(data.refresh_token)
        await redis_storage.delete_token(user_id)

        return {"message": "Logout successful"}
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An unexpected error occurred",
        )


# Access Token, Refresh Token 갱신
@router.post("/refresh", tags=["auth"])
async def refresh_token(
    data: RefreshTokenRequest,
    user_manager: BaseUserManager[models.UP, models.ID] = Depends(get_user_manager),
    jwt_strategy: CustomJWTStrategy = Depends(get_custom_jwt_strategy),
):
    try:
        user_id = await jwt_strategy.validate_refresh_token(data.refresh_token)

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


# 인증 및 사용자 관련 라우터 추가
router.include_router(
    fastapi_users.get_register_router(UserRead, UserCreate), tags=["auth"]
)
router.include_router(fastapi_users.get_reset_password_router(), tags=["auth"])
router.include_router(fastapi_users.get_verify_router(UserRead), tags=["auth"])
router.include_router(
    fastapi_users.get_users_router(UserRead, UserUpdate), tags=["auth"]
)
