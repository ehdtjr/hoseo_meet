from unittest import TestCase

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

    async def test_get_users_by_ids_returns_users(self):
        user_crud = UserCRUD()

        # Given: DB에 2명의 User 추가
        user_data1 = {
            "email": "test1@example.com",
            "hashed_password": "hashedpassword1",
            "name": "Test User 1",
            "gender": "male",
            "is_active": True,
            "is_superuser": False,
            "is_verified": True,
            "is_online": False,
        }

        user_data2 = {
            "email": "test2@example.com",
            "hashed_password": "hashedpassword2",
            "name": "Test User 2",
            "gender": "female",
            "is_active": True,
            "is_superuser": False,
            "is_verified": True,
            "is_online": False,
        }

        user1 = User(**user_data1)
        user2 = User(**user_data2)
        self.db.add_all([user1, user2])
        await self.db.commit()
        await self.db.refresh(user1)
        await self.db.refresh(user2)

        user_ids = [user1.id, user2.id]

        # When: 유효한 ID 리스트로 호출
        result = await user_crud.get_users_by_ids(self.db, user_ids)

        # Then: 두 명의 유저 정보가 정확히 반환되는지 확인
        self.assertEqual(len(result), 2)
        returned_ids = [r.id for r in result]
        self.assertIn(user1.id, returned_ids)
        self.assertIn(user2.id, returned_ids)

        user1_result = next((u for u in result if u.id == user1.id), None)
        user2_result = next((u for u in result if u.id == user2.id), None)

        self.assertIsNotNone(user1_result)
        self.assertIsNotNone(user2_result)
        self.assertEqual(user1_result.email, "test1@example.com")
        self.assertEqual(user1_result.name, "Test User 1")
        self.assertEqual(user2_result.email, "test2@example.com")
        self.assertEqual(user2_result.name, "Test User 2")

    async def test_get_users_by_ids_with_empty_list_returns_empty_list(self):
        user_crud = UserCRUD()

        # Given: 빈 리스트로 호출
        empty_result = await user_crud.get_users_by_ids(self.db, [])

        # Then: 빈 리스트 반환 확인
        self.assertIsInstance(empty_result, list)
        self.assertEqual(len(empty_result), 0)

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
