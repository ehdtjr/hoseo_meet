import json
from datetime import datetime, timedelta, timezone
from typing import Optional

import httpx
import jwt
from fastapi import HTTPException, status
from fastapi_users import models
from fastapi_users.authentication.strategy import JWTStrategy

from app.core.config import settings
from app.core.redis import RedisClient

SECRET_KEY = settings.SECRET_KEY
ALGORITHM = "HS256"


# Refreshtoken 저장 클래스
class RedisTokenStorage:
    def __init__(self, redis_client: RedisClient):
        self.redis_client = redis_client

    async def store_token(self, user_id: str, token: str, expires_in: int) -> None:
        key = f"refresh_token:{user_id}"
        value = {"user_id": user_id, "token": token, "expires_in": expires_in}
        await self.redis_client.redis.set(key, json.dumps(value), ex=expires_in)

    async def read_token(self, user_id: str) -> Optional[dict]:
        key = f"refresh_token:{user_id}"
        value = await self.redis_client.redis.get(key)
        if value:
            return json.loads(value)
        return None

    async def delete_token(self, user_id: str) -> None:
        key = f"refresh_token:{user_id}"
        await self.redis_client.redis.delete(key)


# JWT 토큰 클래스
class CustomJWTStrategy(JWTStrategy):
    def __init__(
        self, secret: str, lifetime_seconds: int, token_storage: RedisTokenStorage
    ):
        super().__init__(secret, lifetime_seconds)
        self.access_lifetime_seconds = lifetime_seconds
        self.refresh_lifetime_seconds = lifetime_seconds * 24 * 14
        self.token_storage = token_storage

    def _generate_token(self, user_id: str, expires_in: int, token_type: str) -> str:
        payload = {
            "sub": user_id,  # 오직 user_id만 저장
            "type": token_type,  # 토큰 타입을 별도 필드로 관리
            "exp": datetime.now(timezone.utc) + timedelta(seconds=expires_in),
            "aud": ["fastapi-users:auth"],
        }
        return jwt.encode(payload, self.secret, algorithm=ALGORITHM)

    async def write_token(self, user: models.UP) -> dict:
        user_id = str(user.id)
        access_token = self._generate_token(
            user_id=user_id,
            expires_in=self.access_lifetime_seconds,
            token_type="access",
        )
        refresh_token = self._generate_token(
            user_id=user_id,
            expires_in=self.refresh_lifetime_seconds,
            token_type="refresh",
        )

        # refresh_token 저장
        await self.token_storage.store_token(
            user_id=user_id,
            token=refresh_token,
            expires_in=self.refresh_lifetime_seconds,
        )

        return {"access_token": access_token, "refresh_token": refresh_token}

    # Refresh Token 유효성 검사
    async def validate_refresh_token(self, refresh_token: str) -> str:
        try:
            payload = jwt.decode(
                refresh_token,
                self.secret,
                algorithms=[ALGORITHM],
                audience="fastapi-users:auth",
            )
            user_id = payload.get("sub")
            token_type = payload.get("type")

            if not user_id or token_type != "refresh":
                raise ValueError("Invalid token payload or token type")

            # Redis에서 토큰 확인 (토큰 일치 여부 확인 권장)
            stored_token = await self.token_storage.read_token(user_id)
            if not stored_token or stored_token.get("token") != refresh_token:
                raise ValueError("Refresh token not found, mismatched or expired in store")

            return user_id
        except jwt.ExpiredSignatureError:
            raise ValueError("Refresh token expired")
        except jwt.InvalidTokenError:
            raise ValueError("Invalid refresh token")

    async def decode_token(self, token: str) -> dict:
        try:
            decoded = jwt.decode(
                token,
                self.secret,
                algorithms=[ALGORITHM],
                audience="fastapi-users:auth",
            )
            return decoded
        except jwt.ExpiredSignatureError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="토큰이 만료되었습니다.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        except jwt.InvalidTokenError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="유효하지 않은 토큰입니다.",
                headers={"WWW-Authenticate": "Bearer"},
            )


# 카카오 user 정보 조회
async def get_kakao_user_data(access_token: str) -> dict:
    headers = {"Authorization": f"Bearer {access_token}"}
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                "https://kapi.kakao.com/v2/user/me", headers=headers
            )
            response.raise_for_status()  # 요청 오류 시 예외 발생
            kakao_user_data = response.json()
            return kakao_user_data

    except httpx.RequestError as e:
        raise HTTPException(status_code=400, detail=f"Request Error: {e}")
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"An unexpected error occurred: {e}"
        )
