from app.crud.stream import StreamCRUD, SubscriptionCRUD, get_subscription_crud
from app.models import Stream
from app.models import Subscription, User
from app.models.recipient import Recipient
from app.schemas.recipient import RecipientType
from app.schemas.stream import StreamCreate, SubscriptionCreate
from app.tests.conftest import BaseTest


class TestStreamCRUD(BaseTest):
    async def test_create(self):
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

        recipient = Recipient(type=1, type_id=user_id)
        self.db.add(recipient)
        await self.db.commit()
        await self.db.refresh(recipient)

        stream_crud = StreamCRUD()
        stream_data = StreamCreate(
            name="Test Stream",
            type="배달",
            creator_id=user_id,
        )

        # when
        result = await stream_crud.create(self.db, stream_data)

        # then
        self.assertIsNotNone(result)
        self.assertEqual(result.name, "Test Stream")
        self.assertEqual(result.creator_id, user_id)

    async def test_get_stream(self):
        # given
        await self.test_create()

        stream_crud = StreamCRUD()

        # when
        result = await stream_crud.get(self.db, 1)

        # then
        self.assertIsNotNone(result)
        self.assertEqual(result.id, 1)
        self.assertEqual(result.name, "Test Stream")

    async def test_update_stream(self):
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

        recipient = Recipient(type=1, type_id=user_id)
        self.db.add(recipient)
        await self.db.commit()
        await self.db.refresh(recipient)

        stream_crud = StreamCRUD()
        stream_data = StreamCreate(
            name="Test Stream",
            type="happy",
            creator_id=user_id,
        )
        result = await stream_crud.create(self.db, stream_data)
        result.name = "Updated Stream"
        # when
        result = await stream_crud.update(self.db, result)

        # then
        self.assertIsNotNone(result)
        self.assertEqual(result.id, 1)
        self.assertEqual(result.name, "Updated Stream")

    async def test_delete(self):
        # given
        await self.test_create()

        stream_crud = StreamCRUD()

        # when
        await stream_crud.delete(self.db, 1)

        # then
        result = await stream_crud.get(self.db, 1)
        self.assertIsNone(result)


class TestSubscriptionCRUD(BaseTest):
    async def test_create(self):
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

        recipient = Recipient(type=RecipientType.USER.value, type_id=user_id)
        self.db.add(recipient)
        await self.db.commit()
        await self.db.refresh(recipient)
        recipient_id = recipient.id

        subscription_crud = get_subscription_crud()
        subscription_data = SubscriptionCreate(
            user_id=user_id,
            recipient_id=recipient.id,
            active=True,
            is_user_active=True,
            is_muted=False,
        )

        # # when
        result = await subscription_crud.create(self.db, subscription_data)
        #
        # then
        self.assertIsNotNone(result)
        self.assertEqual(result.user_id, user_id)
        self.assertEqual(result.recipient_id, recipient_id)

    async def test_get_subscribers(self):
        user_data_1 = {
            "email": "user1@example.com",
            "hashed_password": "hashedpassword",
            "name": "User 1",
            "gender": "male",
            "is_active": True,
            "is_superuser": False,
            "is_verified": True,
        }
        user_data_2 = {
            "email": "user2@example.com",
            "hashed_password": "hashedpassword",
            "name": "User 2",
            "gender": "male",
            "is_active": True,
            "is_superuser": False,
            "is_verified": True,
        }

        user1 = User(**user_data_1)
        user2 = User(**user_data_2)

        self.db.add_all([user1, user2])
        await self.db.commit()
        await self.db.refresh(user1)
        await self.db.refresh(user2)
        user1_id = user1.id
        user2_id = user2.id

        # Create a stream recipient
        recipient = Recipient(type=RecipientType.STREAM.value,
                              type_id=1)  # 예시 stream_id = 1
        self.db.add(recipient)
        await self.db.commit()
        await self.db.refresh(recipient)
        recipient_id = recipient.id

        # 구독 CRUD 사용
        subscription_crud = get_subscription_crud()

        # Create subscriptions for both users to the same stream
        subscription_data_1 = Subscription(
            user_id=user1_id,  # user 객체 대신 user.id 전달
            recipient_id=recipient_id,  # recipient 객체 대신 recipient.id 전달
            active=True,
            is_user_active=True,
            is_muted=False,
        )
        subscription_data_2 = Subscription(
            user_id=user2_id,  # user 객체 대신 user.id 전달
            recipient_id=recipient_id,  # recipient 객체 대신 recipient.id 전달
            active=True,
            is_user_active=True,
            is_muted=False,
        )

        self.db.add_all([subscription_data_1, subscription_data_2])
        await self.db.commit()

        # when: 스트림에 구독된 사용자 목록 가져오기
        result = await subscription_crud.get_subscribers(self.db, stream_id=1)

        print(result)
        # then: 결과 확인
        self.assertEqual(len(result), 2)  # 구독된 사용자 수는 2명이어야 함
        self.assertIn(user1_id, result)  # user1이 구독자 목록에 있어야 함
        self.assertIn(user2_id, result)  # user2도 구독자 목록에 있어야 함

    async def test_get_subscribers_is_not_subscribe(self):
        user_data_1 = {
            "email": "user1@example.com",
            "hashed_password": "hashedpassword",
            "name": "User 1",
            "gender": "male",
            "is_active": True,
            "is_superuser": False,
            "is_verified": True,
        }
        user_data_2 = {
            "email": "user2@example.com",
            "hashed_password": "hashedpassword",
            "name": "User 2",
            "gender": "male",
            "is_active": True,
            "is_superuser": False,
            "is_verified": True,
        }

        user1 = User(**user_data_1)
        user2 = User(**user_data_2)

        self.db.add_all([user1, user2])
        await self.db.commit()
        await self.db.refresh(user1)
        await self.db.refresh(user2)
        user1_id = user1.id
        user2_id = user2.id

        # Create a stream recipient?
        recipient = Recipient(type=RecipientType.STREAM.value,
                              type_id=1)  # 예시 stream_id = 1
        self.db.add(recipient)
        await self.db.commit()
        await self.db.refresh(recipient)
        recipient_id = recipient.id

        # 구독 CRUD 사용
        subscription_crud = get_subscription_crud()

        # Create subscriptions for both users to the same stream
        subscription_data_1 = Subscription(
            user_id=user1_id,  # user 객체 대신 user.id 전달
            recipient_id=recipient_id,  # recipient 객체 대신 recipient.id 전달
            active=True,
            is_user_active=True,
            is_muted=False,
        )
        self.db.add_all([subscription_data_1])
        await self.db.commit()

        # when: 스트림에 구독된 사용자 목록 가져오기
        result = await subscription_crud.get_subscribers(self.db, stream_id=1)

        # then: 결과 확인
        self.assertEqual(len(result), 1)  # 구독된 사용자 수는 2명이어야 함
        self.assertIn(user1_id, result)  # user1이 구독자 목록에 있어야 함
        self.assertNotIn(user2_id, result)  # user2도 구독자 목록에 있어야 함

    async def test_get_subscription_list(self):
        # given: 두 명의 사용자 생성
        user_data_1 = {
            "email": "user1@example.com",
            "hashed_password": "hashedpassword",
            "name": "User 1",
            "gender": "male",
            "is_active": True,
            "is_superuser": False,
            "is_verified": True,
        }
        user_data_2 = {
            "email": "user2@example.com",
            "hashed_password": "hashedpassword",
            "name": "User 2",
            "gender": "male",
            "is_active": True,
            "is_superuser": False,
            "is_verified": True,
        }

        user1 = User(**user_data_1)
        user2 = User(**user_data_2)

        self.db.add_all([user1, user2])
        await self.db.commit()
        await self.db.refresh(user1)
        await self.db.refresh(user2)
        user1_id = user1.id
        user2_id = user2.id

        # 스트림 생성 및 사용자 1이 생성자
        stream = Stream(name="Test Stream", creator_id=user1_id, type="배달")
        self.db.add(stream)
        await self.db.commit()
        await self.db.refresh(stream)
        stream_id = stream.id

        # 스트림에 대한 recipient 생성
        recipient = Recipient(type=RecipientType.STREAM.value,
                              type_id=stream_id)
        self.db.add(recipient)
        await self.db.commit()
        await self.db.refresh(recipient)

        # 구독 CRUD 사용
        subscription_crud = SubscriptionCRUD()

        # 두 명의 사용자가 스트림을 구독
        subscription_data_1 = Subscription(
            user_id=user1_id,
            recipient_id=recipient.id,
            active=True,
            is_user_active=True,
            is_muted=False,
        )
        subscription_data_2 = Subscription(
            user_id=user2_id,
            recipient_id=recipient.id,
            active=True,
            is_user_active=True,
            is_muted=True,
        )

        self.db.add_all([subscription_data_1, subscription_data_2])
        await self.db.commit()

        # when: 첫 번째 사용자의 구독 리스트를 가져오기
        result = await subscription_crud.get_subscription_list(self.db,
                                                               user1_id)

        # then: 결과 확인
        self.assertEqual(len(result), 1)  # 구독된 스트림은 1개여야 함
        stream_result, subscription_result = result[0]
        self.assertEqual(stream_result.id, stream_id)  # 스트림 ID가 정확해야 함
        self.assertEqual(stream_result.creator_id, user1_id)  # 생성자는 사용자 1이어야 함
        self.assertEqual(stream_result.name, "Test Stream")  # 스트림 이름이 정확해야 함
        self.assertFalse(subscription_result.is_muted)  # 구독 상태 확인 (is_muted)

    async def test_get_subscription_list_no_subscriptions(self):
        # given: 구독하지 않은 사용자 생성
        user_data = {
            "email": "nonsubscriber@example.com",
            "hashed_password": "hashedpassword",
            "name": "Non Subscriber",
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

        # when: 구독하지 않은 사용자의 구독 리스트를 가져오기
        subscription_crud = SubscriptionCRUD()
        result = await subscription_crud.get_subscription_list(self.db,
                                                               user_id)

        # then: 결과 확인
        self.assertEqual(len(result), 0)  # 구독된 스트림이 없어야 함
