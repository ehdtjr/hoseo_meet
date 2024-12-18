from app.service.auth import CustomJWTStrategy
from fastapi import APIRouter, Depends, HTTPException, status, Header
from app.core.security import auth_backend, get_custom_jwt_strategy
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
import jwt

router = APIRouter()

api_key_header = APIKeyHeader(name="Authorization", auto_error=False)

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

    #access_token, refresh_token 생성
    tokens = await jwt_strategy.write_token(user)

    return {"message": "login successful", "access_token": tokens["access_token"], "refresh_token": tokens["refresh_token"]}   

# 토큰 재발급
# @router.post("/refresh", response_model=Token)
# async def refresh_token(
#     authorization: str = Depends(api_key_header),
# ):
#     if not authorization or not authorization.startswith("Bearer "):
#         raise HTTPException(
#             status_code=status.HTTP_401_UNAUTHORIZED,
#             detail="Invalid or missing refresh token",
#         )
#     refresh_token = authorization.split(" ")[1]
#     user_id = await verify_token(refresh_token, token_type="refresh")
#     # 사용자 유효성 검사
#     tokens = await generate_tokens(user_id)
#     return tokens

# JWT 토큰 디코딩
@router.get("/jwt/decode", tags=["auth"])
async def decode_jwt_token(
    authorization: Optional[str] = Depends(api_key_header),  # Authorization 헤더에서 JWT 토큰 추출
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