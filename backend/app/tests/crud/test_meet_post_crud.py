from app.crud.meet_post_crud import get_meet_post_crud
from app.models import MeetPost, User
from app.schemas.meet_post_schemas import MeetPostBase, MeetPostCreate
from app.tests.conftest import BaseTest


class TestMeetPostCRUD(BaseTest):
    async def test_create(self):
        user_data = {
            "email": "testuser@example.com",
            "hashed_password": "hashedpassword",
            "name": "Test User",
            "gender": "male",
            "is_active": True,
            "is_superuser": False,
            "is_verified": True,
        }

        user = User(**user_data)
        self.db.add(user)
        await self.db.commit()
        await self.db.refresh(user)
        user_id = user.id  # ID 저장

        # when
        meet_post_crud = get_meet_post_crud()
        meet_post_data = MeetPostCreate(
            author_id=user_id,
            title="Test MeetPost",
            type="meet",
            content="Test MeetPost Content",
            max_people=3
        )
        meet_post = await meet_post_crud.create(self.db, meet_post_data)

        # then
        meet_post_in_db = await self.db.get(MeetPost, meet_post.id)

        self.assertIsNotNone(meet_post_in_db)
        self.assertEqual(meet_post_in_db.id, meet_post.id)
        self.assertEqual(meet_post_in_db.author_id, user_id)
        self.assertEqual(meet_post_in_db.title, "Test MeetPost")
        self.assertEqual(meet_post_in_db.type, "meet")
        self.assertEqual(meet_post_in_db.content, "Test MeetPost Content")
        self.assertEqual(meet_post_in_db.max_people, 3)

    async def test_get(self):
        # given
        user_data = {
            "email": "testuser@example.com",
            "hashed_password": "hashedpassword",
            "name": "Test User",
            "gender": "male",
            "is_active": True,
            "is_superuser": False,
            "is_verified": True,
        }

        user = User(**user_data)
        self.db.add(user)
        await self.db.commit()
        await self.db.refresh(user)
        user_id = user.id  # ID 저장

        meet_post_data = {
            "author_id": user_id,
            "title": "Test MeetPost",
            "type": "meet",
            "content": "Test MeetPost Content",
            "max_people": 3
        }
        meet_post = MeetPost(**meet_post_data)
        self.db.add(meet_post)
        await self.db.commit()
        await self.db.refresh(meet_post)
        meet_post_id = meet_post.id

        # when
        meet_post_crud = get_meet_post_crud()
        meet_post = await meet_post_crud.get(self.db, meet_post_id)
        meet_post_in_db = await self.db.get(MeetPost, meet_post_id)

        # then
        self.assertIsNotNone(meet_post)
        self.assertIsNotNone(meet_post_in_db)
        self.assertEqual(meet_post.id, meet_post_in_db.id)
        self.assertEqual(meet_post.author_id, meet_post_in_db.author_id)
        self.assertEqual(meet_post.title, meet_post_in_db.title)
        self.assertEqual(meet_post.type, meet_post_in_db.type)
        self.assertEqual(meet_post.content, meet_post_in_db.content)
        self.assertEqual(meet_post.max_people, meet_post_in_db.max_people)


    async def test_update(self):
        # given
        user_data = {
            "email": "testuser@example.com",
            "hashed_password": "hashedpassword",
            "name": "Test User",
            "gender": "male",
            "is_active": True,
            "is_superuser": False,
            "is_verified": True,
        }

        user = User(**user_data)
        self.db.add(user)
        await self.db.commit()
        await self.db.refresh(user)
        user_id = user.id  # ID 저장

        meet_post_data = {
            "author_id": user_id,
            "title": "Test MeetPost",
            "type": "meet",
            "content": "Test MeetPost Content",
            "max_people": 3
        }
        meet_post = MeetPost(**meet_post_data)
        self.db.add(meet_post)
        await self.db.commit()
        await self.db.refresh(meet_post)
        meet_post_id = meet_post.id

        # when
        meet_post_crud = get_meet_post_crud()

        # 기존 객체를 가져와 값을 업데이트
        meet_post_in_db = await self.db.get(MeetPost, meet_post_id)
        meet_post_in_db.title = "Updated MeetPost"
        meet_post_in_db.content = "Updated MeetPost Content"
        meet_post_in_db.max_people = 5  # max_people 값도 업데이트

        meet_post_in_db = MeetPostBase.model_validate(meet_post_in_db)
        await meet_post_crud.update(self.db, meet_post_in_db)

        # then
        updated_meet_post_in_db = await self.db.get(MeetPost, meet_post_id)
        self.assertIsNotNone(updated_meet_post_in_db)
        self.assertEqual(updated_meet_post_in_db.id, meet_post_id)
        self.assertEqual(updated_meet_post_in_db.author_id, user_id)
        self.assertEqual(updated_meet_post_in_db.title, "Updated MeetPost")
        self.assertEqual(updated_meet_post_in_db.type, "meet")
        self.assertEqual(updated_meet_post_in_db.content, "Updated MeetPost Content")
        self.assertEqual(updated_meet_post_in_db.max_people, 5)