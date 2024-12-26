# app/scripts/create_bulk_users.py
import asyncio
import traceback
from typing import Any

from app.api.deps import get_user_db
from app.schemas.user import UserCreate
from app.service.user import UserManager
from app.core.db import get_async_session_context


# ------------------------------------------------------
# Stub Verification Service
# ------------------------------------------------------
class StubVerificationService:
    async def create_verification_token(self, user: Any) -> str:
        return "dummy-token"


# ------------------------------------------------------
# Stub Email Service
# ------------------------------------------------------
class StubEmailService:
    """스텁 버전: 실제 메일 전송/도메인 검증/인증 로직을 단순화."""

    def __init__(self):
        self.verification_service = StubVerificationService()

    async def send_email_verification_link(self, user: Any) -> None:
        token = await self.verification_service.create_verification_token(user)
        print(f"[Stub] Skipping real email. user={user.email}, token={token}")

    def validate_email_domain(self, email: str) -> bool:
        # 항상 True 반환(테스트 시 도메인 제한 없음)
        return True


def get_stub_email_service() -> StubEmailService:
    return StubEmailService()


# ------------------------------------------------------
# Bulk User Creation
# ------------------------------------------------------
async def create_bulk_users(count: int = 500):
    for i in range(count):
        async with get_async_session_context() as session:
            try:
                user_db_dep = await anext(get_user_db(session))
                email_svc_dep = get_stub_email_service()

                user_manager = UserManager(user_db_dep, email_svc_dep)

                email_idx = i + 1
                user_in = UserCreate(
                    email=f"test{email_idx}@vision.hoseo.edu",
                    password="test123",
                    is_active=True,
                    is_superuser=False,
                    is_verified=True,
                    name=f"User{email_idx}",
                    gender="unknown",
                    profile="default_profile",
                )

                new_user = await user_manager.create(user_in)
                print(f"[OK] Created user: {new_user.email} (id: {new_user.id})")

            except Exception as e:
                print(f"[ERR] Failed to create user {user_in.email}: {e}")
                traceback.print_exc()


async def main():
    await create_bulk_users(500)


if __name__ == "__main__":
    asyncio.run(main())
