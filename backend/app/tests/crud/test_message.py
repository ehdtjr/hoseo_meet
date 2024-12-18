from sqlalchemy import select

from app.crud.message import (MessageCRUD, get_message_crud,
                              get_user_message_crud)
from app.models import Recipient, User
from app.models.message import Message, UserMessage
from app.schemas.message import MessageCreate, MessageType, UserMessageCreate
from app.schemas.recipient import RecipientCreate, RecipientType
from app.service.stream import get_stream_service
from app.tests.conftest import BaseTest


class TestMessageCRUD(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()
        # Create a user for sender
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
        self.user_id = user.id  # Save user ID for use in tests

        # Create a recipient (stream 1)
        recipient_data = RecipientCreate(type=RecipientType.STREAM, type_id=1)
        recipient = Recipient(**recipient_data.model_dump())
        self.db.add(recipient)
        await self.db.commit()
        await self.db.refresh(recipient)
        self.recipient_id = recipient.id  # Save recipient ID for use in tests

        # Create another recipient (stream 2)
        recipient_data = RecipientCreate(type=RecipientType.STREAM, type_id=2)
        recipient = Recipient(**recipient_data.model_dump())
        self.db.add(recipient)
        await self.db.commit()
        await self.db.refresh(recipient)
        self.recipient_id2 = recipient.id  # Save recipient ID for use in tests

    async def test_create_message(self):
        message_crud = get_message_crud()
        message_data = MessageCreate(
            sender_id=self.user_id,  # Use the created user's ID
            type=MessageType.NORMAL,
            recipient_id=self.recipient_id,  # Use the created recipient's ID
            content="Test message",
            rendered_content="<p>Test message</p>"
        )

        # when
        await message_crud.create(self.db, message_data)

        # then
        result = await self.db.get(Message, 1)

        self.assertIsNotNone(result)
        self.assertEqual(result.id, 1)
        self.assertEqual(result.sender_id, self.user_id)  # Verify sender ID
        self.assertEqual(result.type, MessageType.NORMAL)  # Compare with enum
        self.assertEqual(result.recipient_id,
                         self.recipient_id)  # Verify recipient ID
        self.assertEqual(result.content, "Test message")
        self.assertEqual(result.rendered_content, "<p>Test message</p>")

    async def test_get_message(self):
        message_crud = MessageCRUD()
        message_data = MessageCreate(
            sender_id=self.user_id,  # Use the created user's ID
            type=MessageType.NORMAL,
            recipient_id=self.recipient_id,  # Use the created recipient's ID
            content="Test message",
            rendered_content="<p>Test message</p>"
        )
        await message_crud.create(self.db, message_data)

        # when
        result = await message_crud.get(self.db, 1)

        # then
        self.assertIsNotNone(result)
        self.assertEqual(result.id, 1)
        self.assertEqual(result.sender_id, self.user_id)  # Verify sender ID
        self.assertEqual(result.type,
                         MessageType.NORMAL)  # Compare with enum directly
        self.assertEqual(result.recipient_id,
                         self.recipient_id)  # Verify recipient ID
        self.assertEqual(result.content, "Test message")
        self.assertEqual(result.rendered_content, "<p>Test message</p>")

    async def test_get_stream_messages(self):
        message_crud = get_message_crud()

        # Create multiple messages in the stream for testing
        for i in range(1, 6):
            message_data = MessageCreate(
                sender_id=self.user_id,
                type=MessageType.NORMAL,
                recipient_id=self.recipient_id,
                content=f"Test message {i}",
                rendered_content=f"<p>Test message {i}</p>"
            )
            created_message = await message_crud.create(self.db, message_data)

        # Define anchor (ID of the 3rd message)
        anchor_id = 3

        # when
        messages = await message_crud.get_stream_messages(
            self.db, stream_id=self.recipient_id,
            anchor_id=anchor_id,
            num_before=2, num_after=2
        )

        # then
        self.assertEqual(len(messages), 5)  # 2 before, anchor, 2 after
        self.assertEqual(messages[0].content, "Test message 1")  # First before
        self.assertEqual(messages[1].content, "Test message 2")  # Second before
        self.assertEqual(messages[2].content, "Test message 3")  # Anchor
        self.assertEqual(messages[3].content, "Test message 4")  # First after
        self.assertEqual(messages[4].content, "Test message 5")  # Second after

    async def test_get_stream_messages_not_enough_before_messages(self):
        # 메시지 CRUD 객체 가져오기
        message_crud = get_message_crud()

        # 스트림에 3개의 메시지 생성 (앵커 이전에 충분한 메시지가 없는 케이스)
        for i in range(1, 4):
            message_data = MessageCreate(
                sender_id=self.user_id,
                type=MessageType.NORMAL,
                recipient_id=self.recipient_id,
                content=f"Test message {i}",
                rendered_content=f"<p>Test message {i}</p>"
            )
            await message_crud.create(self.db, message_data)

        # 앵커를 2번째 메시지로 설정
        anchor_id = 2
        messages = await message_crud.get_stream_messages(
            self.db, stream_id=self.recipient_id,
            anchor_id=anchor_id,
            num_before=2, num_after=2
        )

        # 앵커 이전에 충분한 메시지가 없으므로 3개의 메시지만 반환됨
        self.assertEqual(len(messages), 3)
        self.assertEqual(messages[0].content, "Test message 1")
        self.assertEqual(messages[1].content, "Test message 2")
        self.assertEqual(messages[2].content, "Test message 3")

    async def test_get_stream_messages_not_enough_after_messages(self):
        # 메시지 CRUD 객체 가져오기
        message_crud = get_message_crud()

        # 스트림에 3개의 메시지 생성 (앵커 이후에 충분한 메시지가 없는 케이스)
        for i in range(1, 4):
            message_data = MessageCreate(
                sender_id=self.user_id,
                type=MessageType.NORMAL,
                recipient_id=self.recipient_id,
                content=f"Test message {i}",
                rendered_content=f"<p>Test message {i}</p>"
            )
            await message_crud.create(self.db, message_data)

        # 앵커를 2번째 메시지로 설정
        anchor_id = 2
        messages = await message_crud.get_stream_messages(
            self.db, stream_id=self.recipient_id,
            anchor_id=anchor_id,
            num_before=2, num_after=2
        )

        # 앵커 이후에 충분한 메시지가 없으므로 3개의 메시지만 반환됨
        self.assertEqual(len(messages), 3)
        self.assertEqual(messages[0].content, "Test message 1")
        self.assertEqual(messages[1].content, "Test message 2")
        self.assertEqual(messages[2].content, "Test message 3")

    async def test_get_stream_messages_with_nonexistent_anchor(self):
        # 메시지 CRUD 객체 가져오기
        message_crud = get_message_crud()

        # 스트림에 3개의 메시지 생성
        for i in range(1, 4):
            message_data = MessageCreate(
                sender_id=self.user_id,
                type=MessageType.NORMAL,
                recipient_id=self.recipient_id,
                content=f"Test message {i}",
                rendered_content=f"<p>Test message {i}</p>"
            )
            await message_crud.create(self.db, message_data)

        # 존재하지 않는 앵커 ID를 사용하여 메시지 조회
        anchor_id = 999
        messages = await message_crud.get_stream_messages(
            self.db, stream_id=self.recipient_id,
            anchor_id=anchor_id,
            num_before=2, num_after=2
        )

        # 존재하지 않는 앵커이므로 빈 리스트 반환 기대
        self.assertEqual(len(messages), 0)

    async def test_get_stream_messages_with_no_messages_in_stream(self):
        # 메시지 CRUD 객체 가져오기
        message_crud = get_message_crud()

        # 스트림에 메시지가 없는 상태에서 호출
        anchor_id = 1
        messages = await message_crud.get_stream_messages(
            self.db, stream_id=self.recipient_id,
            anchor_id=anchor_id,
            num_before=2, num_after=2
        )

        # 스트림에 메시지가 없으므로 빈 리스트 반환 기대
        self.assertEqual(len(messages), 0)

    async def test_get_stream_messages_with_anchor_as_first_message(self):
        # 메시지 CRUD 객체 가져오기
        message_crud = get_message_crud()

        # 스트림에 3개의 메시지 생성
        for i in range(1, 4):
            message_data = MessageCreate(
                sender_id=self.user_id,
                type=MessageType.NORMAL,
                recipient_id=self.recipient_id,
                content=f"Test message {i}",
                rendered_content=f"<p>Test message {i}</p>"
            )
            await message_crud.create(self.db, message_data)

        # 앵커가 첫 번째 메시지인 경우를 테스트
        anchor_id = 1
        messages = await message_crud.get_stream_messages(
            self.db, stream_id=self.recipient_id,
            anchor_id=anchor_id,
            num_before=2, num_after=2
        )

        # 앵커 이전에 메시지가 없으므로 전체 3개 메시지만 반환됨
        self.assertEqual(len(messages), 3)
        self.assertEqual(messages[0].content, "Test message 1")
        self.assertEqual(messages[1].content, "Test message 2")
        self.assertEqual(messages[2].content, "Test message 3")

    async def test_get_stream_messages_with_anchor_as_last_message(self):
        # 메시지 CRUD 객체 가져오기
        message_crud = get_message_crud()

        # 스트림에 3개의 메시지 생성
        for i in range(1, 4):
            message_data = MessageCreate(
                sender_id=self.user_id,
                type=MessageType.NORMAL,
                recipient_id=self.recipient_id,
                content=f"Test message {i}",
                rendered_content=f"<p>Test message {i}</p>"
            )
            await message_crud.create(self.db, message_data)

        # 앵커가 마지막 메시지인 경우를 테스트
        anchor_id = 3
        messages = await message_crud.get_stream_messages(
            self.db, stream_id=self.recipient_id,
            anchor_id=anchor_id,
            num_before=2, num_after=2
        )

        # 앵커 이후에 메시지가 없으므로 전체 3개 메시지만 반환됨
        self.assertEqual(len(messages), 3)
        self.assertEqual(messages[0].content, "Test message 1")
        self.assertEqual(messages[1].content, "Test message 2")
        self.assertEqual(messages[2].content, "Test message 3")


    async def test_get_stream_messages_only_from_specific_stream(self):
            message_crud = get_message_crud()
            user_message_crud = get_user_message_crud()
            create_message_ids = []
            # 스트림 1에 메시지 생성
            for i in range(1, 6):
                message_data = MessageCreate(
                    sender_id=self.user_id,
                    type=MessageType.NORMAL,
                    recipient_id=self.recipient_id,
                    content=f"Stream 1 message {i}",
                    rendered_content=f"<p>Stream 1 message {i}</p>"
                )
                created_message = await message_crud.create(self.db, message_data)
                create_message_ids.append(created_message.id)

                # UserMessage 생성
                user_message_data = UserMessageCreate(
                    user_id=self.user_id,
                    message_id=created_message.id,
                    is_read=False
                )
                await user_message_crud.create(self.db, user_message_data)

            # 스트림 2에 메시지 생성
            other_stream_id = self.recipient_id2
            for i in range(1, 4):
                message_data = MessageCreate(
                    sender_id=self.user_id,
                    type=MessageType.NORMAL,
                    recipient_id=other_stream_id,
                    content=f"Stream 2 message {i}",
                    rendered_content=f"<p>Stream 2 message {i}</p>"
                )
                created_message = await message_crud.create(self.db, message_data)

                # UserMessage 생성
                user_message_data = UserMessageCreate(
                    user_id=self.user_id,
                    message_id=created_message.id,
                    is_read=False
                )
                await user_message_crud.create(self.db, user_message_data)

            # 스트림 1의 3번째 메시지를 앵커로 설정
            anchor_id = create_message_ids[2]

            # 스트림 1에서만 메시지 조회
            messages = await message_crud.get_stream_messages(
                self.db, stream_id=self.recipient_id, anchor_id=anchor_id,
                num_before=2, num_after=2
            )

            self.assertEqual(len(messages), 5)
            for message in messages:
                self.assertTrue(message.content.startswith("Stream 1"))


class TestUserMessageCRUD(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()
        # Create a user for sender
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
        self.user_id = user.id  # Save user ID for use in tests

        # Create a recipient
        recipient_data = RecipientCreate(type=RecipientType.STREAM, type_id=1)
        recipient = Recipient(**recipient_data.model_dump())
        self.db.add(recipient)
        await self.db.commit()
        await self.db.refresh(recipient)
        self.recipient_id = recipient.id  # Save recipient ID for use in tests

        # Create a message
        message_data = MessageCreate(
            sender_id=self.user_id,
            type=MessageType.NORMAL,
            recipient_id=self.recipient_id,
            content="Test message for bulk creation",
            rendered_content="<p>Test message for bulk creation</p>"
        )
        message_crud = get_message_crud()
        self.message = await message_crud.create(self.db, message_data)

    async def test_bulk_create(self):
        subscribers = [self.user_id for _ in
                       range(3)]  # Create 3 mock subscribers

        # Create UserMessage data for each subscriber
        user_messages_data = [
            {"user_id": subscriber, "message_id": self.message.id}
            for subscriber in subscribers
        ]

        # Get the UserMessageCRUD instance and bulk create
        user_message_crud = get_user_message_crud()
        await user_message_crud.bulk_create(self.db, user_messages_data)

        # Verify that 3 UserMessage objects were created
        result = await self.db.execute(
            select(UserMessage).where(UserMessage.message_id == self.message.id)
        )
        user_messages = result.scalars().all()

        self.assertEqual(len(user_messages), 3)
        for user_message in user_messages:
            self.assertEqual(user_message.message_id, self.message.id)

    async def test_get_newest_message_in_stream(self):
        user_message_crud = get_user_message_crud()
        stream_id = 4
        recipient_data = RecipientCreate(type=RecipientType.STREAM,
            type_id=stream_id)
        recipient = Recipient(**recipient_data.model_dump())
        self.db.add(recipient)
        await self.db.commit()
        await self.db.refresh(recipient)
        recipient_id = recipient.id  # Save recipient ID for use in tests

        # Create several messages in the stream
        message_crud = get_message_crud()
        messages = []
        for i in range(1, 6):
            message_data = MessageCreate(
                sender_id=self.user_id,
                type=MessageType.NORMAL,
                recipient_id=recipient_id,
                content=f"Test message {i}",
                rendered_content=f"<p>Test message {i}</p>"
            )
            created_message = await message_crud.create(self.db, message_data)
            messages.append(created_message)

            # Create UserMessage
            user_message_data = UserMessageCreate(
                user_id=self.user_id,
                message_id=created_message.id,
                is_read=False
            )
            await user_message_crud.create(self.db, user_message_data)

        # Get the newest message in the stream
        newest_message = await user_message_crud.get_newest_message_in_stream(
            self.db, user_id=self.user_id, stream_id=stream_id
        )

        # Assert that the newest message is the last created message
        self.assertIsNotNone(newest_message)
        self.assertEqual(newest_message.message_id, messages[-1].id)

    async def test_get_oldest_message_in_stream(self):
        user_message_crud = get_user_message_crud()
        stream_id = 4
        recipient_data = RecipientCreate(type=RecipientType.STREAM,
                                         type_id=stream_id)
        recipient = Recipient(**recipient_data.model_dump())
        self.db.add(recipient)
        await self.db.commit()
        await self.db.refresh(recipient)
        recipient_id = recipient.id  # Save recipient ID for use in tests

        # Create several messages in the stream
        message_crud = get_message_crud()
        messages = []
        for i in range(1, 6):
            message_data = MessageCreate(
                sender_id=self.user_id,
                type=MessageType.NORMAL,
                recipient_id=recipient_id,
                content=f"Test message {i}",
                rendered_content=f"<p>Test message {i}</p>"
            )
            created_message = await message_crud.create(self.db, message_data)
            messages.append(created_message)

            # Create UserMessage
            user_message_data = UserMessageCreate(
                user_id=self.user_id,
                message_id=created_message.id,
                is_read=False
            )
            await user_message_crud.create(self.db, user_message_data)

        # Get the oldest message in the stream
        oldest_message = await user_message_crud.get_oldest_message_in_stream(
            self.db, user_id=self.user_id, stream_id=stream_id
        )

        # Assert that the oldest message is the first created message
        self.assertIsNotNone(oldest_message)
        self.assertEqual(oldest_message.message_id, messages[0].id)

    async def test_get_first_unread_message_in_stream(self):
        user_message_crud = get_user_message_crud()

        stream_id = 4
        recipient_data = RecipientCreate(type=RecipientType.STREAM,
                                         type_id=stream_id)
        recipient = Recipient(**recipient_data.model_dump())
        self.db.add(recipient)
        await self.db.commit()
        await self.db.refresh(recipient)
        recipient_id = recipient.id  # Save recipient ID for use in tests

        # Create several messages in the stream
        message_crud = get_message_crud()
        messages = []
        for i in range(1, 6):
            message_data = MessageCreate(
                sender_id=self.user_id,
                type=MessageType.NORMAL,
                recipient_id=recipient_id,
                content=f"Test message {i}",
                rendered_content=f"<p>Test message {i}</p>"
            )
            created_message = await message_crud.create(self.db, message_data)
            messages.append(created_message)

            # Create UserMessage
            user_message_data = UserMessageCreate(
                user_id=self.user_id,
                message_id=created_message.id,
                is_read=(i < 3)  # Mark first 2 messages as read
            )
            await user_message_crud.create(self.db, user_message_data)

        # Get the first unread message in the stream
        first_unread_message = await (
            user_message_crud.get_first_unread_message_in_stream(
                self.db, user_id=self.user_id, stream_id=stream_id
            ))

        # Assert that the first unread message is the 3rd message
        self.assertIsNotNone(first_unread_message)
        self.assertEqual(first_unread_message.message_id, messages[2].id)

    async def test_get_first_unread_message_with_previous_read_errors(self):
        user_message_crud = get_user_message_crud()

        stream_id = 4
        recipient_data = RecipientCreate(type=RecipientType.STREAM, type_id=stream_id)
        recipient = Recipient(**recipient_data.model_dump())
        self.db.add(recipient)
        await self.db.commit()
        await self.db.refresh(recipient)
        recipient_id = recipient.id  # Save recipient ID for use in tests

        # Create several messages in the stream
        message_crud = get_message_crud()
        messages = []
        for i in range(1, 6):
            message_data = MessageCreate(
                sender_id=self.user_id,
                type=MessageType.NORMAL,
                recipient_id=recipient_id,
                content=f"Test message {i}",
                rendered_content=f"<p>Test message {i}</p>"
            )
            created_message = await message_crud.create(self.db, message_data)
            messages.append(created_message)

            if i  >= 5:
                user_message_data = UserMessageCreate(
                    user_id=self.user_id,
                    message_id=created_message.id,
                    is_read= False  # Mark all messages as read except for the
                )
                await user_message_crud.create(self.db, user_message_data)

        # Get the first unread message in the stream
        first_unread_message = await user_message_crud.get_first_unread_message_in_stream(
            self.db, user_id=self.user_id, stream_id=stream_id
        )
        # Assert that the first unread message is indeed the 3rd message
        self.assertIsNotNone(first_unread_message)
        self.assertEqual(first_unread_message.message_id, messages[4].id)


    async def test_get_first_unread_message_in_stream_count(self):
        user_message_crud = get_user_message_crud()

        stream_id = 4
        recipient_data = RecipientCreate(type=RecipientType.STREAM,
                                         type_id=stream_id)
        recipient = Recipient(**recipient_data.model_dump())
        self.db.add(recipient)
        await self.db.commit()
        await self.db.refresh(recipient)
        recipient_id = recipient.id  # Save recipient ID for use in tests

        # Create several messages in the stream
        message_crud = get_message_crud()
        messages = []
        for i in range(1, 6):
            message_data = MessageCreate(
                sender_id=self.user_id,
                type=MessageType.NORMAL,
                recipient_id=recipient_id,
                content=f"Test message {i}",
                rendered_content=f"<p>Test message {i}</p>"
            )
            created_message = await message_crud.create(self.db, message_data)
            messages.append(created_message)

            # Create UserMessage
            user_message_data = UserMessageCreate(
                user_id=self.user_id,
                message_id=created_message.id,
                is_read=(i < 3)  # Mark first 2 messages as read
            )
            await user_message_crud.create(self.db, user_message_data)

        # Get the count of unread messages in the stream
        unread_count = await (
            user_message_crud.get_first_unread_message_in_stream_count(
                self.db, user_id=self.user_id, stream_id=stream_id
            ))

        # Assert that the count of unread messages is correct (3 unread
        # messages: 3rd, 4th, and 5th)
        self.assertEqual(unread_count, 3)

    async def test_mark_stream_messages_read(self):
        user_message_crud = get_user_message_crud()
        message_crud = get_message_crud()
        stream_id = 4
        recipient_data = RecipientCreate(type=RecipientType.STREAM,
                                         type_id=stream_id)
        recipient = Recipient(**recipient_data.model_dump())
        self.db.add(recipient)
        await self.db.commit()
        await self.db.refresh(recipient)
        recipient_id = recipient.id  # Save recipient ID for use in tests

        messages = []
        for i in range(1, 6):
            message_data = MessageCreate(
                sender_id=self.user_id,
                type=MessageType.NORMAL,
                recipient_id=recipient_id,
                content=f"Test message {i}",
                rendered_content=f"<p>Test message {i}</p>"
            )
            created_message = await message_crud.create(self.db, message_data)
            messages.append(created_message)

            # Create UserMessage
            user_message_data = UserMessageCreate(
                user_id=self.user_id,
                message_id=created_message.id,
                is_read=False
            )
            await user_message_crud.create(self.db, user_message_data)

        # 특정 앵커 메시지와 범위 지정
        anchor_id = messages[2].id  # 3번째 메시지를 앵커로 설정
        num_before = 2
        num_after = 2

        # when
        await user_message_crud.mark_stream_messages_read(self.db,
                                                          user_id=self.user_id,
                                                          stream_id=stream_id,
                                                          anchor_id=anchor_id,
                                                          num_before=num_before,
                                                          num_after=num_after)

        # 범위 내 모든 메시지가 읽음 처리되었는지 확인
        anchor_index = next(
            i for i, msg in enumerate(messages) if msg.id == anchor_id)
        start_index = max(0, anchor_index - num_before)
        end_index = min(len(messages), anchor_index + num_after + 1)

        messages_to_check = messages[start_index:end_index]

        # 결과 검증 - 범위 내 모든 메시지가 읽음 처리되었는지 확인
        for message in messages_to_check:
            user_message_result = await self.db.execute(
                select(UserMessage).where(UserMessage.user_id == self.user_id,
                                          UserMessage.message_id == message.id)
            )
            user_message = user_message_result.scalar_one_or_none()
            self.assertIsNotNone(user_message)
            self.assertTrue(user_message.is_read)
