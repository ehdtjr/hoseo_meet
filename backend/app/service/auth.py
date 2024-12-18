from datetime import datetime, timedelta
from fastapi_users.authentication.strategy import JWTStrategy
from fastapi_users import models
import jwt
from app.core.config import settings
from datetime import datetime, timedelta, timezone
from fastapi import HTTPException
import httpx

SECRET_KEY = settings.SECRET_KEY
ALGORITHM = "HS256"


class CustomJWTStrategy(JWTStrategy):
    def __init__(self, secret: str, lifetime_seconds: int):
        super().__init__(secret, lifetime_seconds)
        self.access_lifetime_seconds = lifetime_seconds
        self.refresh_lifetime_seconds = lifetime_seconds * 24 * 14

    def _generate_token(self, user_id: str, expires_in: int, token_type: str) -> str:
        payload = {
            "sub": f"{user_id}.{token_type}",
            "exp": datetime.now(timezone.utc) + timedelta(seconds=expires_in),
            "aud": ["fastapi-users:auth"],
        }
        return jwt.encode(payload, self.secret, algorithm=ALGORITHM)

    async def write_token(self, user: models.UP) -> dict:
        access_token = self._generate_token(
            user_id=str(user.id),
            expires_in=self.lifetime_seconds,
            token_type="access"
        )
        refresh_token = self._generate_token(
            user_id=str(user.id),
            expires_in=self.refresh_lifetime_seconds,
            token_type="refresh"
        )
        return {"access_token": access_token, "refresh_token": refresh_token}

    async def read_refresh_token(self, token: str) -> str:
        try:
            payload = jwt.decode(token, self.secret, algorithms=[ALGORITHM])
            return payload.get("sub")
        except jwt.ExpiredSignatureError:
            raise ValueError("Refresh token expired")
        except jwt.InvalidTokenError:
            raise ValueError("Invalid refresh token")

    async def decode_token(token: str) -> dict:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])


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
