from app.service.auth import CustomJWTStrategy
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
from app.core.config import settings

# CustomJWTStrategy 의존성 주입
def get_custom_jwt_strategy() -> CustomJWTStrategy:
    return CustomJWTStrategy(
        secret=settings.SECRET_KEY,
        lifetime_seconds=3600,  # 1시간 유효 기간
    )

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
