import uuid

from fastapi_users import FastAPIUsers
from fastapi_users.authentication import (
    JWTStrategy,
    AuthenticationBackend,
    BearerTransport,
)

from app.core.config import settings
from app.service.user import get_user_manager
from app.models.user import User

bearer_transport = BearerTransport(tokenUrl="auth/jwt/login")


def get_jwt_strategy(lifetime_seconds: int = 3600) -> JWTStrategy:
    return JWTStrategy(secret=settings.SECRET_KEY, lifetime_seconds=lifetime_seconds)


auth_backend = AuthenticationBackend(
    name="jwt",
    transport=bearer_transport,
    get_strategy=get_jwt_strategy,
)

fastapi_users = FastAPIUsers[User, uuid.UUID](get_user_manager, [auth_backend])
