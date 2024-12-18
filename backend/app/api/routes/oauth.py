from app.core.db import get_async_session
from app.core.security import get_custom_jwt_strategy
from app.service.auth import CustomJWTStrategy,get_kakao_user_data
from fastapi import APIRouter, Depends, HTTPException, status, Header
from app.service.user import UserManager, get_user_manager
from typing import Optional
from fastapi.security import APIKeyHeader
import os, requests, httpx
from app.schemas.user import UserUpdate, KakaoUserUpdate
from app.models.user import User, OAuthAccount  # User 모델 import 필요
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.core.config import settings

router = APIRouter()

api_key_header = APIKeyHeader(name="Authorization", auto_error=False)

# 카카오 로그인
@router.get("/kakao/login", tags=["oauth"])
async def get_kakao_login(
    authorization: Optional[str] = Depends(api_key_header),
    user_manager: UserManager = Depends(get_user_manager),
    db: AsyncSession = Depends(get_async_session),  # 비동기 세션 주입
    jwt_strategy: CustomJWTStrategy = Depends(get_custom_jwt_strategy),
) -> dict:
    # authorization 헤더에서 토큰 추출
    access_token = authorization.split(" ")[1]

    try:
        kakao_user_data = await get_kakao_user_data(access_token)

        account_id = kakao_user_data.get("id")
        email = kakao_user_data.get("kakao_account", {}).get("email")

        oauth_result = await user_manager.oauth_callback("kakao", access_token, str(account_id), email)
        
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

        #access_token, refresh_token 생성
        tokens = await jwt_strategy.write_token(user)

        return {"message": "Kakao login successful","access_token": tokens["access_token"], "refresh_token": tokens["refresh_token"]}
        
    except httpx.RequestError as e:
        raise HTTPException(
            status_code=400,
            detail=f"Request Error: {e}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"An unexpected error occurred: {e}"
        )

# 첫 로그인 후 name, gender update
@router.post("/kakao/is_first_login/update", tags=["oauth"])
async def update_user(
    user_update: KakaoUserUpdate,  # UserUpdate 스키마를 통해 업데이트할 데이터 받기
    user_manager: UserManager = Depends(get_user_manager),
    authorization: Optional[str] = Depends(api_key_header),
    db: AsyncSession = Depends(get_async_session),  # 비동기 세션 주입
    jwt_strategy: CustomJWTStrategy = Depends(get_custom_jwt_strategy),
):
    # authorization 헤더에서 토큰 추출
    token = authorization.split(" ")[1]

    try:
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

        #access_token, refresh_token 생성
        tokens = await jwt_strategy.write_token(updated_user)

        # 인앱 JWT 토큰 발급
        return {"message": "User information updated successfully", "access_token": tokens["access_token"], "refresh_token": tokens["refresh_token"]}
    
    except httpx.RequestError as e:
        raise HTTPException(
            status_code=400,
            detail=f"Request Error: {e}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"An unexpected error occurred: {e}"
        )

# 카카오 액세스 토큰 갱신
# @router.get("/kakao/refresh-access_token", tags=["oauth"])
# async def refresh_kakao_access_token(
#     user_manager: UserManager = Depends(get_user_manager),
#     authorization: Optional[str] = Depends(api_key_header),
#     db: AsyncSession = Depends(get_async_session),
# ) -> dict:

#     # authorization 헤더에서 토큰 추출
#     token = authorization.split(" ")[1]

#     # OAuthAccount에서 access_token을 기준으로 refresh_token 조회
#     result = await db.execute(
#         select(OAuthAccount).where(OAuthAccount.access_token == token)
#     )
#     oauth_entry = result.scalars().first()

#     if oauth_entry is None:
#         raise HTTPException(status_code=404, detail="OAuth account not found")

#     refresh_token = oauth_entry.refresh_token

#     kakao_token_url = "https://kauth.kakao.com/oauth/token"
#     headers = {"Content-Type": "application/x-www-form-urlencoded"}
#     data = {
#         "grant_type": "refresh_token",
#         "client_id": os.getenv("KAKAO_OAUTH_CLIENT_ID"),
#         "refresh_token": refresh_token,
#     }

#     # 새로운 액세스 토큰 요청
#     async with httpx.AsyncClient() as client:
#         response = await client.post(kakao_token_url, headers=headers, data=data)

#     if response.status_code == 200:
#         token_data = response.json()

#         # 새로운 access_token과 refresh_token 업데이트
#         update_data = {"access_token": token_data["access_token"]}
#         if "refresh_token" in token_data:
#             update_data["refresh_token"] = token_data["refresh_token"]

#         updated_user = await user_manager.user_db.update(oauth_entry, update_data)

#         return {
#             "message": "Kakao access token refreshed successfully",
#             "access_token": token_data["access_token"],
#         }

#     elif response.status_code == 401:
#         raise HTTPException(status_code=401, detail="Invalid refresh token")
#     else:
#         raise HTTPException(
#             status_code=response.status_code,
#             detail=f"Failed to refresh access token: {response.text}",
#         )