from unittest.mock import AsyncMock


from app.crud.recipient import RecipientCRUDProtocol
from app.crud.stream import SubscriptionCRUDProtocol
from app.models import Recipient, Stream, Subscription
from app.models import User
from app.schemas.recipient import RecipientBase, RecipientType
from app.schemas.stream import StreamBase, StreamCreate, SubscriptionBase
from app.schemas.user import UserRead
from app.service.stream import SubscriberService, get_stream_service, \
    get_subscription_service
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


    async def test_unsubscribe(self):
        mock_subscription_id = 1
        mock_user_id = 1
        mock_recipient_id = 1
        mock_stream_id = 1

        subscription_crud: SubscriptionCRUDProtocol = AsyncMock(
        spec=SubscriptionCRUDProtocol)

        subscription_crud.get_subscribers.return_value = [1, 2, 3]

        recipient_crud: RecipientCRUDProtocol = AsyncMock(
            spec=RecipientCRUDProtocol)

        recipient_crud.get_by_type_id.return_value = RecipientBase(
            id=mock_recipient_id,
            type=RecipientType.STREAM.value,
            type_id=mock_stream_id
        )

        subscription_crud.get_subscription.return_value = SubscriptionBase(
            id=mock_subscription_id,
            user_id=mock_user_id,
            recipient_id=mock_recipient_id,
            active=True,
            is_user_active=True,
            is_muted=False
        )

        subscription_crud.update.return_value = SubscriptionBase(
            id=mock_subscription_id,
            user_id=mock_user_id,
            recipient_id=mock_recipient_id,
            active=False,
            is_user_active=True,
            is_muted=False
        )

        # when
        subscription_service = SubscriberService(
            subscription_crud=subscription_crud,
            stream_crud=AsyncMock(),
            recipient_crud=recipient_crud,
            user_message_crud=AsyncMock(),
            message_crud=AsyncMock(),
        )

        result:SubscriptionBase = await subscription_service.unsubscribe(self.db,
            mock_user_id,
            mock_subscription_id)

        # then
        self.assertIsNotNone(result)
        self.assertFalse(result.active)

    async def test_unsubscribe_user_not_subscribed(self):
        # given: 구독되지 않은 사용자가 해제를 시도하는 경우
        mock_user_id = 1
        mock_stream_id = 1
        mock_recipient_id = 1

        subscription_crud: SubscriptionCRUDProtocol = AsyncMock(
            spec=SubscriptionCRUDProtocol
        )
        subscription_crud.get_subscribers.return_value = [2, 3, 4]  # user_id가 포함되지 않음

        recipient_crud: RecipientCRUDProtocol = AsyncMock(
            spec=RecipientCRUDProtocol
        )
        recipient_crud.get_by_type_id.return_value = RecipientBase(
            id=mock_recipient_id,
            type=RecipientType.STREAM.value,
            type_id=mock_stream_id
        )

        subscription_service = SubscriberService(
            subscription_crud=subscription_crud,
            stream_crud=AsyncMock(),
            recipient_crud=recipient_crud,
            user_message_crud=AsyncMock(),
            message_crud=AsyncMock(),
        )

        # when / then
        with self.assertRaises(ValueError) as context:
            await subscription_service.unsubscribe(self.db, mock_user_id, mock_stream_id)
        self.assertEqual(str(context.exception), f"User {mock_user_id} is not subscribed")

    async def test_unsubscribe_recipient_not_found(self):
        # given: 수신자가 없는 경우
        mock_user_id = 1
        mock_stream_id = 1

        subscription_crud: SubscriptionCRUDProtocol = AsyncMock(
            spec=SubscriptionCRUDProtocol
        )
        subscription_crud.get_subscribers.return_value = [1, 2, 3]

        recipient_crud: RecipientCRUDProtocol = AsyncMock(
            spec=RecipientCRUDProtocol
        )
        recipient_crud.get_by_type_id.return_value = None  # 수신자가 없는 경우

        subscription_service = SubscriberService(
            subscription_crud=subscription_crud,
            stream_crud=AsyncMock(),
            recipient_crud=recipient_crud,
            user_message_crud=AsyncMock(),
            message_crud=AsyncMock(),
        )

        # when / then
        with self.assertRaises(ValueError) as context:
            await subscription_service.unsubscribe(self.db, mock_user_id, mock_stream_id)
        self.assertEqual(str(context.exception), f"Recipient not found for stream {mock_stream_id}")

    async def test_unsubscribe_subscription_not_found(self):
        # given: 구독 정보가 없는 경우
        mock_user_id = 1
        mock_stream_id = 1
        mock_recipient_id = 1

        subscription_crud: SubscriptionCRUDProtocol = AsyncMock(
            spec=SubscriptionCRUDProtocol
        )
        subscription_crud.get_subscribers.return_value = [1, 2, 3]

        recipient_crud: RecipientCRUDProtocol = AsyncMock(
            spec=RecipientCRUDProtocol
        )
        recipient_crud.get_by_type_id.return_value = RecipientBase(
            id=mock_recipient_id,
            type=RecipientType.STREAM.value,
            type_id=mock_stream_id
        )

        subscription_crud.get_subscription.return_value = None  # 구독 정보가 없음

        subscription_service = SubscriberService(
            subscription_crud=subscription_crud,
            stream_crud=AsyncMock(),
            recipient_crud=recipient_crud,
            user_message_crud=AsyncMock(),
            message_crud=AsyncMock(),
        )

        # when / then
        with self.assertRaises(ValueError) as context:
            await subscription_service.unsubscribe(self.db, mock_user_id, mock_stream_id)
        self.assertEqual(str(context.exception), f"Subscription not found for user {mock_user_id}")

    async def test_unsubscribe_already_inactive(self):
        # given: 이미 비활성화된 구독이 존재하는 경우
        mock_user_id = 1
        mock_stream_id = 1
        mock_recipient_id = 1
        mock_subscription_id = 1

        subscription_crud: SubscriptionCRUDProtocol = AsyncMock(
            spec=SubscriptionCRUDProtocol
        )
        subscription_crud.get_subscribers.return_value = [1, 2, 3]

        recipient_crud: RecipientCRUDProtocol = AsyncMock(
            spec=RecipientCRUDProtocol
        )
        recipient_crud.get_by_type_id.return_value = RecipientBase(
            id=mock_recipient_id,
            type=RecipientType.STREAM.value,
            type_id=mock_stream_id
        )

        # 이미 비활성화된 구독을 반환
        subscription_crud.get_subscription.return_value = SubscriptionBase(
            id=mock_subscription_id,
            user_id=mock_user_id,
            recipient_id=mock_recipient_id,
            active=False,  # 비활성화된 구독
            is_user_active=True,
            is_muted=False
        )

        subscription_service = SubscriberService(
            subscription_crud=subscription_crud,
            stream_crud=AsyncMock(),
            recipient_crud=recipient_crud,
            user_message_crud=AsyncMock(),
            message_crud=AsyncMock(),
        )

        # when / then
        with self.assertRaises(ValueError) as context:
            await subscription_service.unsubscribe(self.db, mock_user_id, mock_stream_id)
        self.assertEqual(str(context.exception), f"Subscription is already inactive")
