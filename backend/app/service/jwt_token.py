from datetime import datetime, timedelta
from fastapi_users.authentication.strategy import JWTStrategy
from fastapi_users import models
import jwt
from app.core.config import settings
from datetime import datetime, timedelta, timezone

SECRET_KEY = settings.SECRET_KEY
ALGORITHM = "HS256"


class CustomJWTStrategy(JWTStrategy):
    def __init__(self, secret: str, lifetime_seconds: int, refresh_lifetime_days: int):

        super().__init__(secret, lifetime_seconds)
        self.refresh_lifetime_days = refresh_lifetime_days

    async def write_token(self, user: models.UP) -> dict:
        """
        Generate both access_token and refresh_token for the user.
        """
        # Access Token 생성
        access_token_payload = {
            "sub": str(user.id),
            "exp": datetime.now(timezone.utc) + timedelta(seconds=3600),
            "aud": ["fastapi-users:auth"],
        }
        access_token = jwt.encode(
            access_token_payload, self.secret, algorithm=ALGORITHM
        )

        # Refresh Token 생성
        refresh_token_payload = {
            "sub": str(user.id),
            "exp": datetime.now(timezone.utc) + timedelta(seconds=7 * 24 * 60 * 60),
            "aud": ["fastapi-users:auth"],
        }
        refresh_token = jwt.encode(
            refresh_token_payload, self.secret, algorithm=ALGORITHM
        )

        return {"access_token": access_token, "refresh_token": refresh_token}

    async def read_refresh_token(self, token: str) -> str:
        """
        Decode and validate the refresh token.
        """
        try:
            payload = jwt.decode(token, self.secret, algorithms=[ALGORITHM])
            return payload.get("sub")
        except jwt.ExpiredSignatureError:
            raise ValueError("Refresh token expired")
        except jwt.InvalidTokenError:
            raise ValueError("Invalid refresh token")
    
    async def decode_token(token: str) -> dict:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
