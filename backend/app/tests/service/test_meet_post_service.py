from unittest import TestCase

from app.models import User
from app.schemas.meet_post_schemas import MeetPostCreate, MeetPostRequest
from app.schemas.user import UserRead
from app.service.meet_post_service import get_meet_post_service
from app.tests.conftest import BaseTest


from unittest import TestCase
from app.models import User
from app.schemas.meet_post_schemas import MeetPostRequest, MeetPostResponse
from app.schemas.user import UserRead
from app.service.meet_post_service import get_meet_post_service
from app.tests.conftest import BaseTest


class TestMeetPostService(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()
        self.service = get_meet_post_service()

        # 테스트에 필요한 사용자 데이터 생성
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
        self.user = UserRead.model_validate(user)

    async def test_create_meet_post(self):
        # 만남 게시글 생성 데이터
        meet_post_request = MeetPostRequest(
            title="Test Meet Post",
            type="meet",
            content="This is a test meet post",
            max_people=5
        )

        # 만남 게시글 생성 서비스 호출
        result = await self.service.create_meet_post(self.db,
                                                     meet_post_request,
                                                     user_id=self.user.id)

        # 결과 검증
        self.assertIsNotNone(result)  # 결과가 None이 아닌지 확인
        self.assertEqual(result.title, "Test Meet Post")  # 게시글 제목이 올바른지 확인
        self.assertEqual(result.author_id, self.user.id)  # 게시글 작성자가 올바른지 확인