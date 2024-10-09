from app.crud.user_crud import UserCRUD
from app.models import User
from app.schemas.user import UserUpdate
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
