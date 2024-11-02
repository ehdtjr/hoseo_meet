from fastapi import APIRouter, Depends, HTTPException, status

from app.core.security import auth_backend
from app.service.email import EmailVerificationService, get_email_verification_service
from app.schemas.user import UserRead, UserCreate, UserUpdate
from app.core.security import fastapi_users
from app.service.user import UserManager, get_user_manager, kakao_oauth_client

import os

router = APIRouter()


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
router.include_router(
    fastapi_users.get_register_router(UserRead, UserCreate), tags=["auth"]
)
router.include_router(fastapi_users.get_reset_password_router(), tags=["auth"])
router.include_router(fastapi_users.get_verify_router(UserRead), tags=["auth"])
router.include_router(
    fastapi_users.get_users_router(UserRead, UserUpdate), tags=["auth"]
)
router.include_router(
    fastapi_users.get_oauth_router(
        oauth_client=kakao_oauth_client,
        backend=auth_backend,
        redirect_url="http://localhost:8000/api/v1/auth/kakao/callback",
        state_secret=os.getenv("SECRET_KEY"),
        associate_by_email=True,  # OAuth2 인증을 통해 받아온 이메일 주소가 기존 사용자 이메일과 매칭될 경우, 해당 계정을 연결
    ),
    prefix="/kakao",
    tags=["auth"],
)
