from app.crud.meet_post_crud import get_meet_post_crud
from app.models import MeetPost, User
from app.schemas.meet_post_schemas import MeetPostBase, MeetPostCreate
from app.tests.conftest import BaseTest

from app.models import Stream


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

        stream_data = {
            "name": "Test Stream",
            "type": "meet",
            "creator_id": user_id
        }

        stream = Stream(**stream_data)
        self.db.add(stream)
        await self.db.commit()
        await self.db.refresh(stream)
        stream_id = stream.id

        # when
        meet_post_crud = get_meet_post_crud()
        meet_post_data = MeetPostCreate(
            author_id=user_id,
            stream_id=stream_id,
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

        stream_data = {
            "name": "Test Stream",
            "type": "meet",
            "creator_id": user_id
        }

        stream = Stream(**stream_data)
        self.db.add(stream)
        await self.db.commit()
        await self.db.refresh(stream)
        stream_id = stream.id

        meet_post_data = {
            "author_id": user_id,
            "title": "Test MeetPost",
            "type": "meet",
            "content": "Test MeetPost Content",
            "stream_id": stream_id,
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
        stream_data = {
            "name": "Test Stream",
            "type": "meet",
            "creator_id": user_id
        }

        stream = Stream(**stream_data)
        self.db.add(stream)
        await self.db.commit()
        await self.db.refresh(stream)
        stream_id = stream.id

        meet_post_data = {
            "author_id": user_id,
            "stream_id": stream_id,
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

    async def test_get_filtered_posts_title(self):
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

        stream_data = {
            "name": "Test Stream",
            "type": "meet",
            "creator_id": user_id
        }

        stream = Stream(**stream_data)
        self.db.add(stream)
        await self.db.commit()
        await self.db.refresh(stream)
        stream_id = stream.id

        meet_post_data = {
            "author_id": user_id,
            "stream_id": stream_id,
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

        meet_post_data2 = {
            "author_id": user_id,
            "stream_id": stream_id,
            "title": "happy MeetPost",
            "type": "meet",
            "content": "Test MeetPost Content",
            "max_people": 3
        }
        meet_post2 = MeetPost(**meet_post_data2)
        self.db.add(meet_post2)
        await self.db.commit()
        await self.db.refresh(meet_post2)
        meet_post2_id = meet_post2.id

        # when
        meet_post_crud = get_meet_post_crud()
        search_title = "Test"
        filtered_meet_posts = await meet_post_crud.get_filtered_posts(
            self.db,
            title=search_title)

        # then
        self.assertIsNotNone(filtered_meet_posts)
        self.assertEqual(len(filtered_meet_posts), 1)
        self.assertEqual(filtered_meet_posts[0].id, meet_post_id)

    async def test_get_filtered_posts_no_filter(self):
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
        user_id = user.id

        stream_data = {
            "name": "Test Stream",
            "type": "meet",
            "creator_id": user_id
        }

        stream = Stream(**stream_data)
        self.db.add(stream)
        await self.db.commit()
        await self.db.refresh(stream)
        stream_id = stream.id

        meet_post_data1 = {
            "author_id": user_id,
            "stream_id": stream_id,
            "title": "Test MeetPost",
            "type": "meet",
            "content": "Test MeetPost Content",
            "max_people": 3
        }
        meet_post_data2 = {
            "author_id": user_id,
            "stream_id": stream_id,
            "title": "Another MeetPost",
            "type": "taxi",
            "content": "Another MeetPost Content",
            "max_people": 4
        }
        self.db.add_all(
            [MeetPost(**meet_post_data1), MeetPost(**meet_post_data2)])
        await self.db.commit()

        # when
        meet_post_crud = get_meet_post_crud()
        filtered_meet_posts = await meet_post_crud.get_filtered_posts(self.db)

        # then
        self.assertIsNotNone(filtered_meet_posts)
        self.assertGreaterEqual(len(filtered_meet_posts), 2)

    async def test_get_filtered_posts_title_case_insensitive(self):
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
        user_id = user.id

        stream_data = {
            "name": "Test Stream",
            "type": "meet",
            "creator_id": user_id
        }

        stream = Stream(**stream_data)
        self.db.add(stream)
        await self.db.commit()
        await self.db.refresh(stream)
        stream_id = stream.id

        meet_post_data = {
            "author_id": user_id,
            "stream_id": stream_id,
            "title": "Test MeetPost",
            "type": "meet",
            "content": "Test Content",
            "max_people": 3
        }
        self.db.add(MeetPost(**meet_post_data))
        await self.db.commit()

        # when
        meet_post_crud = get_meet_post_crud()
        search_title = "test"  # 소문자로 검색
        filtered_meet_posts = await meet_post_crud.get_filtered_posts(self.db,
                                                                      title=search_title)

        # then
        self.assertIsNotNone(filtered_meet_posts)
        self.assertEqual(len(filtered_meet_posts), 1)

    async def test_get_filtered_posts_no_results(self):
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
        user_id = user.id

        stream_data = {
            "name": "Test Stream",
            "type": "meet",
            "creator_id": user_id
        }

        stream = Stream(**stream_data)
        self.db.add(stream)
        await self.db.commit()
        await self.db.refresh(stream)
        stream_id = stream.id

        meet_post_data = {
            "author_id": user_id,
            "stream_id": stream_id,
            "title": "Test MeetPost",
            "type": "meet",
            "content": "Test Content",
            "max_people": 3
        }
        self.db.add(MeetPost(**meet_post_data))
        await self.db.commit()

        # when
        meet_post_crud = get_meet_post_crud()
        search_title = "NonExistentTitle"
        filtered_meet_posts = await meet_post_crud.get_filtered_posts(self.db,
                                                                      title=search_title)

        # then
        self.assertIsNotNone(filtered_meet_posts)
        self.assertEqual(len(filtered_meet_posts), 0)

    async def test_get_filtered_posts_type(self):
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

        stream_data = {
            "name": "Test Stream",
            "type": "meet",
            "creator_id": user_id
        }

        stream = Stream(**stream_data)
        self.db.add(stream)
        await self.db.commit()
        await self.db.refresh(stream)
        stream_id = stream.id

        meet_post_data = {
            "author_id": user_id,
            "stream_id": stream_id,
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

        meet_post_data2 = {
            "author_id": user_id,
            "stream_id": stream_id,
            "title": "happy MeetPost",
            "type": "taxi",
            "content": "Test MeetPost Content",
            "max_people": 3
        }
        meet_post2 = MeetPost(**meet_post_data2)
        self.db.add(meet_post2)
        await self.db.commit()
        await self.db.refresh(meet_post2)
        meet_post2_id = meet_post2.id

        # when
        meet_post_crud = get_meet_post_crud()
        search_type = "taxi"
        filtered_meet_posts = await meet_post_crud.get_filtered_posts(
            self.db,post_type=search_type)

        # then
        self.assertIsNotNone(filtered_meet_posts)
        self.assertEqual(len(filtered_meet_posts), 1)
        self.assertEqual(filtered_meet_posts[0].id, meet_post2_id)

    async def test_get_filtered_posts_limit_zero(self):
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
        user_id = user.id

        stream_data = {
            "name": "Test Stream",
            "type": "meet",
            "creator_id": user_id
        }

        stream = Stream(**stream_data)
        self.db.add(stream)
        await self.db.commit()
        await self.db.refresh(stream)
        stream_id = stream.id

        meet_post_data = {
            "author_id": user_id,
            "stream_id": stream_id,
            "title": "Test MeetPost",
            "type": "meet",
            "content": "Test Content",
            "max_people": 3
        }
        self.db.add(MeetPost(**meet_post_data))
        await self.db.commit()

        # when
        meet_post_crud = get_meet_post_crud()
        filtered_meet_posts = await meet_post_crud.get_filtered_posts(self.db,
                                                                      limit=0)

        # then
        self.assertIsNotNone(filtered_meet_posts)
        self.assertEqual(len(filtered_meet_posts), 0)

    async def test_get_filtered_posts_skip_beyond_range(self):
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
        user_id = user.id
        stream_data = {
            "name": "Test Stream",
            "type": "meet",
            "creator_id": user_id
        }

        stream = Stream(**stream_data)
        self.db.add(stream)
        await self.db.commit()
        await self.db.refresh(stream)
        stream_id = stream.id

        meet_post_data = {
            "author_id": user_id,
            "stream_id": stream_id,
            "title": "Test MeetPost",
            "type": "meet",
            "content": "Test Content",
            "max_people": 3
        }
        self.db.add(MeetPost(**meet_post_data))
        await self.db.commit()

        # when
        meet_post_crud = get_meet_post_crud()
        filtered_meet_posts = await meet_post_crud.get_filtered_posts(self.db,
                                                                      skip=1000)

        # then
        self.assertIsNotNone(filtered_meet_posts)
        self.assertEqual(len(filtered_meet_posts), 0)

    async def test_get_filtered_posts_pagination(self):
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
        user_id = user.id

        stream_data = {
            "name": "Test Stream",
            "type": "meet",
            "creator_id": user_id
        }

        stream = Stream(**stream_data)
        self.db.add(stream)
        await self.db.commit()
        await self.db.refresh(stream)
        stream_id = stream.id

        meet_post_data1 = {
            "author_id": user_id,
            "stream_id": stream_id,
            "title": "First MeetPost",
            "type": "meet",
            "content": "First Content",
            "max_people": 3
        }
        meet_post_data2 = {
            "author_id": user_id,
            "stream_id": stream_id,
            "title": "Second MeetPost",
            "type": "taxi",
            "content": "Second Content",
            "max_people": 4
        }
        self.db.add_all(
            [MeetPost(**meet_post_data1), MeetPost(**meet_post_data2)])
        await self.db.commit()

        # when
        meet_post_crud = get_meet_post_crud()
        filtered_meet_posts = await meet_post_crud.get_filtered_posts(self.db,
                                                                      limit=1,
                                                                      skip=1)

        # then
        self.assertIsNotNone(filtered_meet_posts)
        self.assertEqual(len(filtered_meet_posts), 1)  # 두 번째 게시물만 반환되는지 확인

    async def test_get_filtered_posts_multiple_filters(self):
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
        user_id = user.id

        stream_data = {
            "name": "Test Stream",
            "type": "meet",
            "creator_id": user_id
        }

        stream = Stream(**stream_data)
        self.db.add(stream)
        await self.db.commit()
        await self.db.refresh(stream)
        stream_id = stream.id

        meet_post_data1 = {
            "author_id": user_id,
            "stream_id": stream_id,
            "title": "Test MeetPost",
            "type": "meet",
            "content": "Happy Content",
            "max_people": 3
        }
        meet_post_data2 = {
            "author_id": user_id,
            "stream_id": stream_id,
            "title": "Other MeetPost",
            "type": "taxi",
            "content": "Sad Content",
            "max_people": 4
        }
        self.db.add_all(
            [MeetPost(**meet_post_data1), MeetPost(**meet_post_data2)])
        await self.db.commit()

        # when
        meet_post_crud = get_meet_post_crud()
        search_title = "Test"
        search_content = "Happy"
        filtered_meet_posts = await meet_post_crud.get_filtered_posts(self.db,
                                                                      title=search_title,
                                                                      content=search_content)

        # then
        self.assertIsNotNone(filtered_meet_posts)
        self.assertEqual(len(filtered_meet_posts),
                         1)  # 'Test'와 'Happy' 포함된 게시물만 반환되는지 확인

    async def test_get_filtered_posts_content(self):
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

        stream_data = {
            "name": "Test Stream",
            "type": "meet",
            "creator_id": user_id
        }

        stream = Stream(**stream_data)
        self.db.add(stream)
        await self.db.commit()
        await self.db.refresh(stream)
        stream_id = stream.id

        meet_post_data = {
            "author_id": user_id,
            "title": "Test MeetPost",
            "type": "meet",
            "content": "happy MeetPost Content",
            "stream_id": stream_id,
            "max_people": 3
        }

        meet_post = MeetPost(**meet_post_data)
        self.db.add(meet_post)
        await self.db.commit()
        await self.db.refresh(meet_post)
        meet_post_id = meet_post.id

        meet_post_data2 = {
            "author_id": user_id,
            "title": "happy MeetPost",
            "type": "taxi",
            "content": "Test MeetPost Content",
            "stream_id": stream_id,
            "max_people": 3
        }
        meet_post2 = MeetPost(**meet_post_data2)
        self.db.add(meet_post2)
        await self.db.commit()
        await self.db.refresh(meet_post2)
        meet_post2_id = meet_post2.id

        # when
        meet_post_crud = get_meet_post_crud()
        search_content = "happy"
        filtered_meet_posts = await meet_post_crud.get_filtered_posts(
            self.db, content=search_content)

        # then
        self.assertIsNotNone(filtered_meet_posts)
        self.assertEqual(len(filtered_meet_posts), 1)
        self.assertEqual(filtered_meet_posts[0].id, meet_post_id)