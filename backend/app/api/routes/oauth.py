from app.core.db import get_async_session
from fastapi import APIRouter, Depends, HTTPException, status, Header

from app.core.security import auth_backend, get_jwt_strategy
from app.schemas.user import UserRead, UserCreate, UserUpdate
from app.core.security import fastapi_users
from app.service.kakao_oauth import get_oauth_router
from app.service.user import UserManager, get_user_manager, kakao_oauth_client
from typing import Optional
from fastapi.security import APIKeyHeader
import os, requests, httpx
from app.schemas.user import UserUpdate, KakaoUserUpdate
from app.models.user import User, OAuthAccount  # User 모델 import 필요
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from fastapi import APIRouter, Depends, HTTPException, Header, status
from fastapi_users.jwt import decode_jwt
import jwt
from app.core.config import settings

router = APIRouter()

api_key_header = APIKeyHeader(name="Authorization", auto_error=False)

# 카카오 user 정보 조회
async def get_kakao_user_data(access_token: str) -> dict:
    headers = {"Authorization": f"Bearer {access_token}"}
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get("https://kapi.kakao.com/v2/user/me", headers=headers)
            response.raise_for_status()  # 요청 오류 시 예외 발생
            kakao_user_data = response.json()
            return kakao_user_data
        
    except httpx.HTTPStatusError as e:
        print(f"HTTP Error: {e.response.status_code}")
    except httpx.RequestError as e:
        print(f"Request Error: {e}")


# 카카오 로그인
@router.get("/kakao/login", tags=["oauth"])
async def get_kakao_login(
    authorization: Optional[str] = Depends(api_key_header),
    user_manager: UserManager = Depends(get_user_manager),
    db: AsyncSession = Depends(get_async_session),  # 비동기 세션 주입
) -> dict:
    access_token = authorization.split(" ")[1]

    headers = {"Authorization": f"Bearer {access_token}"}
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get("https://kapi.kakao.com/v2/user/me", headers=headers)
            response.raise_for_status()  # 요청 오류 시 예외 발생
            kakao_user_data = response.json()

            account_id = kakao_user_data.get("id")
            nickname = kakao_user_data.get("properties", {}).get("nickname")
            email = kakao_user_data.get("kakao_account", {}).get("email")

            auth_result = await user_manager.oauth_callback("kakao", access_token, str(account_id), email)

            return {"message": "Kakao login successful"}
        
    except httpx.HTTPStatusError as e:
        print(f"HTTP Error: {e.response.status_code}")
    except httpx.RequestError as e:
        print(f"Request Error: {e}")

# 첫 로그인 후 name, gender update
@router.post("/kakao/is_first_login/update", tags=["oauth"])
async def update_user(
    user_update: KakaoUserUpdate,  # UserUpdate 스키마를 통해 업데이트할 데이터 받기
    user_manager: UserManager = Depends(get_user_manager),
    authorization: Optional[str] = Depends(api_key_header),
    db: AsyncSession = Depends(get_async_session),  # 비동기 세션 주입
):
    # authorization 헤더에서 토큰 추출
    token = authorization.split(" ")[1]

    # 카카오 사용자 정보 조회
    kakao_oauth_user = await get_kakao_user_data(token)
    account_id = kakao_oauth_user.get("id")

    # OAuthAccount에서 access_token을 기준으로 사용자 조회
    result = await db.execute(
        select(OAuthAccount).where(OAuthAccount.account_id == str(account_id))
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

    # 사용자 정보 업데이트
    updated_user = await user_manager.user_db.update(
        user, user_update.dict(exclude_unset=True)
    )

    # JWT 토큰 생성
    jwt_token = await get_jwt_strategy().write_token(updated_user)

    print(jwt_token)

    # 인앱 JWT 토큰 발급
    return {"message": "User information updated successfully", "jwt_token": jwt_token}


# 카카오 액세스 토큰 유효성 검증
@router.get("/kakao/verify-access_token", tags=["oauth"])
async def kakao_verify_access_token(authorization: Optional[str] = Header(...)):

    access_token = authorization.split(" ")[1]
    kakao_user_info_url = "https://kapi.kakao.com/v1/user/access_token_info"
    headers = {"Authorization": f"Bearer {access_token}"}

    try:
        # 비동기 HTTP 클라이언트를 사용하여 요청을 보냄
        async with httpx.AsyncClient() as client:
            response = await client.get(kakao_user_info_url, headers=headers)

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

# 카카오 액세스 토큰 갱신
@router.get("/kakao/refresh-access_token", tags=["oauth"])
async def refresh_kakao_access_token(
    user_manager: UserManager = Depends(get_user_manager),
    authorization: Optional[str] = Depends(api_key_header),
    db: AsyncSession = Depends(get_async_session),
) -> dict:

    # authorization 헤더에서 토큰 추출
    token = authorization.split(" ")[1]

    # OAuthAccount에서 access_token을 기준으로 refresh_token 조회
    result = await db.execute(
        select(OAuthAccount).where(OAuthAccount.access_token == token)
    )
    oauth_entry = result.scalars().first()

    if oauth_entry is None:
        raise HTTPException(status_code=404, detail="OAuth account not found")

    refresh_token = oauth_entry.refresh_token

    kakao_token_url = "https://kauth.kakao.com/oauth/token"
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    data = {
        "grant_type": "refresh_token",
        "client_id": os.getenv("KAKAO_OAUTH_CLIENT_ID"),
        "refresh_token": refresh_token,
    }

    # 새로운 액세스 토큰 요청
    async with httpx.AsyncClient() as client:
        response = await client.post(kakao_token_url, headers=headers, data=data)

    if response.status_code == 200:
        token_data = response.json()

        # 새로운 access_token과 refresh_token 업데이트
        update_data = {"access_token": token_data["access_token"]}
        if "refresh_token" in token_data:
            update_data["refresh_token"] = token_data["refresh_token"]

        updated_user = await user_manager.user_db.update(oauth_entry, update_data)

        return {
            "message": "Kakao access token refreshed successfully",
            "access_token": token_data["access_token"],
        }

    elif response.status_code == 401:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    else:
        raise HTTPException(
            status_code=response.status_code,
            detail=f"Failed to refresh access token: {response.text}",
        )

# JWT 토큰 디코딩
@router.get("/jwt/decode", tags=["auth"])
async def decode_jwt_token(
    authorization: Optional[str] = Depends(api_key_header),  # Authorization 헤더에서 JWT 토큰 추출
):
    """
    클라이언트가 Authorization 헤더에 JWT 토큰을 보내면, 이를 디코딩하고 내용을 반환합니다.
    """
    # Authorization 헤더에서 "Bearer " 부분 제거
    token = authorization.split(" ")[1]

    print(token)

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