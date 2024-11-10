from app.core.db import get_async_session
from fastapi import APIRouter, Depends, HTTPException, status, Header

from app.core.security import auth_backend
from app.service.email import EmailVerificationService, get_email_verification_service
from app.schemas.user import UserRead, UserCreate, UserUpdate
from app.core.security import fastapi_users
from app.service.kakao_oauth import get_oauth_router
from app.service.user import UserManager, get_user_manager, kakao_oauth_client
from typing import Optional
from fastapi.security import APIKeyHeader
import os, requests, httpx
from app.schemas.user import UserUpdate,KakaoUserUpdate
from app.models.user import User,OAuthAccount  # User 모델 import 필요
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

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

# 첫 로그인 후 name, gender update
@router.post("/is_first_login/update", tags=["auth"])
async def update_user(
    user_update: KakaoUserUpdate,  # UserUpdate 스키마를 통해 업데이트할 데이터 받기
    user_manager: UserManager = Depends(get_user_manager),
    authorization: Optional[str] = Depends(api_key_header),
    db: AsyncSession = Depends(get_async_session),  # 비동기 세션 주입
):
    # authorization 헤더에서 토큰 추출
    token = authorization.split(" ")[1]
    
    # OAuthAccount에서 access_token을 기준으로 사용자 조회
    result = await db.execute(
        select(OAuthAccount).where(OAuthAccount.access_token == token)
    )
    oauth_entry = result.scalars().first()

    # 해당 access_token으로 등록된 사용자 없음
    if oauth_entry is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="OAuth account not found"
        )

    # user_id로 사용자 객체 조회
    user = await user_manager.user_db.get(oauth_entry.user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )
    
    # 사용자 정보 업데이트 (UserUpdate 스키마의 데이터 사용)
    updated_user = await user_manager.user_db.update(user, user_update.dict(exclude_unset=True))

    return {"message": "User information updated successfully", "user": updated_user}


# 카카오 액세스 토큰 유효성 검증
@router.get("/kakao/verify-access_token", tags=["auth"])
async def kakao_verify_access_token(authorization: Optional[str] = Header(...)):

    access_token = authorization.split(" ")[1]
    kakao_user_info_url = "https://kapi.kakao.com/v1/user/access_token_info"
    headers = {"Authorization": f"Bearer {access_token}"}

    try:
        # 비동기 HTTP 클라이언트를 사용하여 요청을 보냄
        async with httpx.AsyncClient() as client:
            response = await client.get(kakao_user_info_url, headers=headers)
            print(response.json())

        # 성공적인 검증 응답 처리
        if response.status_code == 200:
            return {"message": "Access token is valid", "result": True}

        # 유효하지 않은 토큰 처리
        elif response.status_code == 401:
            return {"message": "Access token is not valid", "result": False}

        # 기타 오류 코드 처리
        raise HTTPException(
            status_code=response.status_code, detail="Failed to verify access token"
        )

    except httpx.RequestError as e:
        # 네트워크 요청 오류 처리
        raise HTTPException(status_code=500, detail=f"Network error: {e}")
    except Exception as e:
        # 기타 예외 처리
        raise HTTPException(
            status_code=500, detail=f"An unexpected error occurred: {e}"
        )


# 카카오 사용자 정보 요청 함수
def get_kakao_user_info(access_token: str):
    kakao_user_info_url = "https://kapi.kakao.com/v2/user/me"
    headers = {"Authorization": f"Bearer {access_token}"}

    response = requests.get(kakao_user_info_url, headers=headers)

    if response.status_code == 200:
        print(response.json())
        return response.json()  # 사용자 정보 반환
    else:
        print(f"카카오 사용자 정보 요청 실패: {response.status_code}")
        return None


# 사용자 정보 요청 엔드포인트
@router.get("/kakao/user-info", tags=["auth"])
async def kakao_user_info(authorization: Optional[str] = Header(...)):

    if authorization is None:
        raise HTTPException(
            status_code=400, detail="Authorization 헤더가 누락되었습니다."
        )

    print("authorization : ", authorization)
    access_token = authorization.split(" ")[1]
    print("access_token : ", access_token)
    user_info = get_kakao_user_info(access_token)

    if user_info is None:
        raise HTTPException(status_code=401, detail="카카오 사용자 정보 조회 실패")

    return {"user_info": user_info}

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


# OAuth2 인증 라우터 추가
router.include_router(
    get_oauth_router(
        oauth_client=kakao_oauth_client,
        get_user_manager=get_user_manager,
        backend=auth_backend,
        redirect_url="http://10.0.2.2:8000/api/v1/auth/kakao/callback",
        state_secret=os.getenv("SECRET_KEY"),
        associate_by_email=True,  # OAuth2 인증을 통해 받아온 이메일 주소가 기존 사용자 이메일과 매칭될 경우, 해당 계정을 연결
    ),
    prefix="/kakao",
    tags=["auth"],
)