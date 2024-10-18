from app.crud.user_crud import UserCRUD, UserFCMTokenCRUD
from app.models import User
from app.schemas.user import UserFCMTokenCreate, UserUpdate
from app.tests.conftest import BaseTest


class TestUserCRUD(BaseTest):
    async def test_update_user(self):
        user_crud = UserCRUD()
        user_data = {
            "email": "duplicate_user@example.com",
            "hashed_password": "hashedpassword",
            "name": "Duplicate User",
            "gender": "male",
            "is_active": True,
            "is_superuser": False,
            "is_verified": True,
            "is_online": False,
        }

        # User 인스턴스 생성 및 DB에 추가
        user = User(**user_data)
        self.db.add(user)
        await self.db.commit()
        await self.db.refresh(user)
        user_id = user.id

        update_data = UserUpdate(is_online=True, id=user_id)

        # when
        result = await user_crud.update(self.db, user_in=update_data)

        # then
        self.assertIsNotNone(result)
        self.assertEqual(result.id, 1)
        self.assertEqual(result.name, "Duplicate User")
        self.assertEqual(result.gender, "male")
        self.assertTrue(result.is_online)

class TestUserFCMTokenCRUD(BaseTest):
    async def test_create_user_fcm_token(self):
        # User 생성
        user_data = {
            "email": "test_user@example.com",
            "hashed_password": "hashedpassword",
            "name": "Test User",
            "gender": "male",
            "is_active": True,
            "is_superuser": False,
            "is_verified": True,
            "is_online": False,
        }

        user = User(**user_data)
        self.db.add(user)
        await self.db.commit()
        await self.db.refresh(user)
        user_id = user.id

        # CRUD 인스턴스 생성
        fcm_token_crud = UserFCMTokenCRUD()

       # FCM 토큰 생성 데이터
        fcm_token_data = UserFCMTokenCreate(
            user_id=user_id,
            fcm_token="test_fcm_token"
        )

       #  # FCM 토큰 생성
        created_fcm_token = await fcm_token_crud.create(self.db, fcm_token_data)
       #
        # 생성된 FCM 토큰이 DB에 올바르게 저장되었는지 확인
        self.assertIsNotNone(created_fcm_token)
        self.assertEqual(created_fcm_token.user_id, user_id)
        self.assertEqual(created_fcm_token.fcm_token, "test_fcm_token")
