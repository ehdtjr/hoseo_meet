from app.models import User
from app.schemas.meet_post_schemas import MeetPostCreate
from app.schemas.user import UserRead
from app.service.meet_post_service import get_meet_post_service
from app.tests.conftest import BaseTest


class TestMeetPostService(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()
        self.service = get_meet_post_service()

    async def test_create_meet_post(self):
        # given: 테스트에 필요한 사용자 데이터 생성
        user_data = {
            "email": "testuser@example.com",
            "hashed_password": "hashedpassword",
            "name": "Test User",
            "gender": "male",
            "is_active": True,
            "is_superuser": False,
            "is_verified": True,
        }

        # 사용자 생성
        user = User(**user_data)
        self.db.add(user)
        await self.db.commit()
        await self.db.refresh(user)
        user = UserRead.model_validate(user)

        # 만남 게시글 생성 데이터
        meet_post_create = MeetPostCreate(
            title="Test Meet Post",
            author_id=user.id,
            type="meet",
            content="This is a test meet post",
            max_people=5
        )

        # when: 만남 게시글 생성 서비스 호출
        result = await self.service.create_meet_post(self.db, meet_post_create)

        # then: 결과 검증
        # 게시판 생성되었는지
        self.assertIsNotNone(result)  # 결과가 None이 아닌지 확인
        self.assertEqual(result.title, "Test Meet Post")  # 게시글 제목이 올바른지 확인
        self.assertEqual(result.author_id, user.id)  # 게시글 작성자가 올바른지 확인