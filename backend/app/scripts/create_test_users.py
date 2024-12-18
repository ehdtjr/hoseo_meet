import asyncio
from faker import Faker
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker
from app.schemas.user import UserCreate
from app.models.user import User as UserModel
from app.service.user import UserManager
from fastapi_users.db import SQLAlchemyUserDatabase
from app.core.config import settings

fake = Faker()

# DATABASE_URL을 문자열로 변환
DATABASE_URL = str(settings.SQLALCHEMY_DATABASE_URI)  # 문자열로 변환
engine = create_async_engine(DATABASE_URL)
async_session = sessionmaker(engine,
     class_=AsyncSession,
     expire_on_commit=False)


class TestUserManager(UserManager):
    async def create(self, user_create, safe=True, request=None):
        # email_service가 None일 때 이메일 검증을 생략
        if self.email_service is not None and not self.email_service.validate_email_domain(
                user_create.email):
            raise ValueError("Invalid email domain.")
        return await super().create(user_create, safe=safe, request=request)


async def create_test_users(user_manager, count=500):
    for i in range(count):
        user_create = UserCreate(
            email=f"test{i}@example.com",
            password="testpassword123",  # 테스트 비밀번호
            is_verified=True,  # 테스트 계정은 활성화된 상태로 설정
            name=f"TestUser{i}",  # 추가된 필드
            gender="unknown"  # 추가된 필드
        )
        await user_manager.create(user_create, safe=True)
    print(f"{count}명의 테스트 계정을 성공적으로 생성했습니다.")


async def main():
    # 세션을 직접 생성하여 user_db 인스턴스를 초기화합니다.
    async with async_session() as session:  # AsyncSession 생성
        # 올바른 인자 순서로 SQLAlchemyUserDatabase 초기화
        user_db = SQLAlchemyUserDatabase(session, UserModel)
        # email_service를 None으로 설정하여 비활성화된 TestUserManager 생성
        user_manager = TestUserManager(user_db=user_db, email_service=None)

        # 테스트 계정 생성 호출
        await create_test_users(user_manager)


# FastAPI 이외의 환경에서 asyncio 루프 시작
asyncio.run(main())
