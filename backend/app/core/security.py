from fastapi import Depends, HTTPException, status
from fastapi_users import FastAPIUsers
from fastapi_users.authentication import (
    AuthenticationBackend,
    BearerTransport,
    JWTStrategy,
)

from app.core.config import settings
from app.models.user import User
from app.service.user import get_user_manager

from datetime import datetime, timedelta, timezone
import jwt
from app.core.config import settings

SECRET_KEY = settings.SECRET_KEY
ALGORITHM = "HS256"

def create_access_token(user_id: str, expires_in: int = 3600) -> str:
    payload = {
        "sub": str(user_id),
        "exp": datetime.now(timezone.utc) + timedelta(seconds=expires_in),
        "aud": ["fastapi-users:auth"],
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def create_refresh_token(user_id: str, expires_in: int = 7 * 24 * 60 * 60) -> str:
    payload = {
        "sub": f"{str(user_id)}.refresh", # refresh token을 구분하기 위해 sub에 .refresh 추가
        "exp": datetime.now(timezone.utc) + timedelta(seconds=expires_in),
        "aud": ["fastapi-users:auth"],
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def decode_token(token: str) -> dict:
    return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])


def get_jwt_strategy(lifetime_seconds: int = 3600) -> JWTStrategy:
    return JWTStrategy(secret=settings.SECRET_KEY, lifetime_seconds=lifetime_seconds)


bearer_transport = BearerTransport(tokenUrl="auth/jwt/login")

auth_backend = AuthenticationBackend(
    name="jwt",
    transport=bearer_transport,
    get_strategy=get_jwt_strategy,
)

fastapi_users = FastAPIUsers[User, int](get_user_manager, [auth_backend])


async def current_active_user(
    user: User = Depends(fastapi_users.current_user(active=True)),
):
    if not user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Email not verified"
        )
    return user
