from app.models import Recipient, Stream
from app.models import User
from app.schemas.recipient import RecipientType
from app.schemas.stream import StreamBase, StreamCreate
from app.schemas.user import UserRead
from app.service.stream import get_stream_service, get_subscription_service
from app.tests.conftest import BaseTest


class TestStreamService(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()
        self.service = get_stream_service()

    async def test_create_stream(self):
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

        # 사용자 생성
        user = User(**user_data)
        self.db.add(user)
        await self.db.commit()
        await self.db.refresh(user)
        user = UserRead.model_validate(user)

        stream_create = StreamCreate(
            name="Test Stream",
            type="배달",
            creator_id=user.id,
        )

        # when
        result = await self.service.create_stream(self.db, stream_create)

        # then
        self.assertIsNotNone(result)  # 결과가 None이 아닌지 확인
        self.assertEqual(result.name, "Test Stream")  # 스트림 이름이 기대한 값인지 확인
        self.assertEqual(result.creator_id, user.id)  # 스트림 이름이 기대한 값인지 확인


class TestSubscriberService(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()
        self.service = get_subscription_service()  # 구독 서비스로 변경

    async def test_subscribe(self):
        # given: 사용자 및 스트림 생성
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

        # 스트림 생성
        stream = Stream(name="Test Stream", creator_id=user.id, type="배달")
        self.db.add(stream)
        await self.db.commit()
        await self.db.refresh(stream)

        recipient = Recipient(type=RecipientType.STREAM.value,
                              type_id=stream.id)
        self.db.add(recipient)
        await self.db.commit()
        await self.db.refresh(recipient)

        stream.recipient_id = recipient.id
        await self.db.commit()
        await self.db.refresh(stream)
        stream = StreamBase.model_validate(stream)
        # when: 사용자 구독
        result = await self.service.subscribe(self.db, user.id, stream.id)

        # then: 구독이 성공적으로 되었는지 확인
        self.assertIsNotNone(result)  # 결과가 None이 아닌지 확인
        self.assertEqual(result.user_id, user.id)  # 구독자가 기대한 값인지 확인
