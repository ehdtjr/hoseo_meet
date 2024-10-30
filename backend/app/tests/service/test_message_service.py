from datetime import datetime, timezone
from unittest.mock import AsyncMock

from app.core.exceptions import PermissionDeniedException
from app.models import Recipient, Stream, User
from app.schemas.message import MessageBase, UserMessageBase
from app.schemas.recipient import RecipientType
from app.tests.conftest import BaseTest


class TestMessageService(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()

        # 메시지 서비스 초기화
        self.message_crud = AsyncMock()
        self.user_message_crud = AsyncMock()
        self.recipient_crud = AsyncMock()
        self.subscription_crud = AsyncMock()
        self.user_crud = AsyncMock()

        from app.service.message import MessageService
        self.service = MessageService(
            message_crud=self.message_crud,
            user_message_crud=self.user_message_crud,
            user_crud= self.user_crud,
            recipient_crud=self.recipient_crud,
            subscription_crud=self.subscription_crud,
        )

        # Redis 모의 객체 생성
        self.redis = AsyncMock()

    async def test_send_message_stream(self):
        # given: 사용자 및 스트림 설정
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
        user_id = user.id

        # 스트림 생성
        stream = Stream(name="Test Stream", creator_id=user_id, type="배달")
        self.db.add(stream)
        await self.db.commit()
        await self.db.refresh(stream)
        stream_id = stream.id

        # 수신자 생성
        recipient = Recipient(type=RecipientType.STREAM.value,
                              type_id=stream_id)
        self.db.add(recipient)
        await self.db.commit()
        await self.db.refresh(recipient)

        stream.recipient_id = recipient.id
        await self.db.commit()
        await self.db.refresh(stream)

        # 메시지 생성 모의 설정
        mock_message = AsyncMock()
        mock_message.id = 1
        mock_message.sender_id = user_id
        mock_message.recipient_id = stream.recipient_id
        mock_message.content = "Test message"
        mock_message.date_sent = datetime.now()  # 현재 시간을 사용하여 date_sent 설정

        self.message_crud.create.return_value = mock_message  # 메시지 생성 모의 설정

        # 모의 구독자 리스트 설정
        self.subscription_crud.get_subscribers.return_value = [user_id]

        # when: 메시지 전송
        message_content = "Test message"
        await self.service.send_message_stream(
            db=self.db,
            redis=self.redis,
            sender_id=user_id,
            stream_id=stream_id,
            message_content=message_content,
        )

        # then: 메시지 전송이 성공적으로 되었는지 검증
        self.recipient_crud.get_by_type_id.assert_called_once_with(self.db,
                                                                   stream.id)
        self.message_crud.create.assert_called_once()

    async def test_send_message_stream_not_subscript(self):
        # given: 사용자 및 스트림 설정
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
        user_id = user.id

        # 스트림 생성
        stream = Stream(name="Test Stream", creator_id=user_id, type="배달")
        self.db.add(stream)
        await self.db.commit()
        await self.db.refresh(stream)
        stream_id = stream.id

        # 수신자 생성
        recipient = Recipient(type=RecipientType.STREAM.value,
                              type_id=stream_id)
        self.db.add(recipient)
        await self.db.commit()
        await self.db.refresh(recipient)

        stream.recipient_id = recipient.id
        await self.db.commit()
        await self.db.refresh(stream)

        # 메시지 생성 모의 설정
        mock_message = AsyncMock()
        mock_message.id = 1
        mock_message.sender_id = user_id
        mock_message.recipient_id = stream.recipient_id
        mock_message.content = "Test message"
        mock_message.date_sent = datetime.now()

        self.message_crud.create.return_value = mock_message  # 메시지 생성 모의 설정

        # 모의 구독자 리스트 설정 (구독자 없음)
        self.subscription_crud.get_subscribers.return_value = []

        # when & then: PermissionDeniedException 발생 확인
        try:
            message_content = "Test message"
            await self.service.send_message_stream(
                db=self.db,
                redis=self.redis,
                sender_id=user_id,
                stream_id=stream_id,
                message_content=message_content,
            )
            # 예외가 발생하지 않으면 실패로 처리
            self.fail("PermissionDeniedException이 발생해야 합니다.")
        except PermissionDeniedException as e:
            # 발생한 예외 메시지가 정확한지 확인
            self.assertEqual(str(e),
                             "You are not permitted to send messages to this "
                             "stream")

        self.message_crud.create.assert_not_called()

    async def test__convert_anchor_to_id_newest(self):
        # given
        newest_message = UserMessageBase(
            id=1,
            user_id=1,
            message_id=3,
            is_read = False
        )
        self.user_message_crud.get_newest_message_in_stream = AsyncMock(
            return_value=newest_message
        )
        # when
        result = await self.service._convert_anchor_to_id(
            db=self.db,
            anchor="newest",
            user_id=1,
            stream_id=1
        )
        # then
        self.assertEqual(result, 3)

    async def test__convert_anchor_to_id_first_unread(self):
        # given
        first_message = UserMessageBase(
            id=1,
            user_id=1,
            message_id=3,
            is_read=False
        )
        self.user_message_crud.get_first_unread_message_in_stream = AsyncMock(
            return_value=first_message
        )
        # when
        result = await self.service._convert_anchor_to_id(
            db=self.db,
            anchor="first_unread",
            user_id=1,
            stream_id=1
        )

        # then
        self.assertEqual(result, 3)

    async def test_get_stream_messages_success(self):
        # given
        current_time = datetime.now(timezone.utc)
        from app.models.message import MessageType
        mock_messages = [
            MessageBase(
                id=1,
                sender_id=1,
                type=MessageType.NORMAL,
                recipient_id=1,
                content="Message 1",
                rendered_content="<p>Message 1</p>",
                date_sent=current_time,
                has_attachment=False,
                has_image=False,
                has_link=False
            ),
            MessageBase(
                id=2,
                sender_id=1,
                type=MessageType.NORMAL,
                recipient_id=1,
                content="Message 2",
                rendered_content="<p>Message 2</p>",
                date_sent=current_time,
                has_attachment=False,
                has_image=False,
                has_link=False
            ),
            MessageBase(
                id=3,
                sender_id=1,
                type=MessageType.NORMAL,
                recipient_id=1,
                content="Message 3",
                rendered_content="<p>Message 3</p>",
                date_sent=current_time,
                has_attachment=False,
                has_image=False,
                has_link=False
            ),
            MessageBase(
                id=4,
                sender_id=1,
                type=MessageType.NORMAL,
                recipient_id=1,
                content="Message 4",
                rendered_content="<p>Message 4</p>",
                date_sent=current_time,
                has_attachment=False,
                has_image=False,
                has_link=False
            ),
            MessageBase(
                id=5,
                sender_id=1,
                type=MessageType.NORMAL,
                recipient_id=1,
                content="Message 5",
                rendered_content="<p>Message 5</p>",
                date_sent=current_time,
                has_attachment=False,
                has_image=False,
                has_link=False
            ),
        ]

        mock_oldest_message = MessageBase(
            id=3,
            sender_id=1,
            type=MessageType.NORMAL,
            recipient_id=1,
            content="Message 3",
            rendered_content="<p>Message 3</p>",
            date_sent=current_time,
            has_attachment=False,
            has_image=False,
            has_link=False
        )

        self.message_crud.get_stream_messages = AsyncMock(return_value=mock_messages)
        self.user_message_crud.get_oldest_message_in_stream = AsyncMock(
            return_value=mock_oldest_message)

        # _check_stream_permission과 _convert_anchor_to_id 모의 설정
        self.service._check_stream_permission = AsyncMock(return_value=True)
        self.service._convert_anchor_to_id = AsyncMock(return_value=3)

        # when
        result = await self.service.get_stream_messages(
            db=self.db,
            user_id=1,
            stream_id=1,
            anchor="3",
            num_before=2,
            num_after=2
        )

        # then
        self.assertEqual(len(result), 3)  # Messages 3, 4, 5만 반환되어야 함
        self.assertEqual(result[0].id, 3)
        self.assertEqual(result[1].id, 4)
        self.assertEqual(result[2].id, 5)

    async def test_get_stream_messages_no_permission(self):
        # given
        self.service._check_stream_permission = AsyncMock(return_value=False)

        # when & then
        with self.assertRaises(PermissionDeniedException) as context:
            await self.service.get_stream_messages(
                db=self.db,
                user_id=1,
                stream_id=1,
                anchor="3",
                num_before=2,
                num_after=2
            )

        self.assertEqual(
            str(context.exception),
            "You are not permitted to read messages from this stream"
        )
    async def test_get_stream_messages_empty_messages(self):
        # given
        self.service._check_stream_permission = AsyncMock(return_value=True)
        self.service._convert_anchor_to_id = AsyncMock(return_value=3)
        self.message_crud.get_stream_messages = AsyncMock(return_value=[])
        self.user_message_crud.get_oldest_message_in_stream = AsyncMock(
            return_value=None)

        # when
        result = await self.service.get_stream_messages(
            db=self.db,
            user_id=1,
            stream_id=1,
            anchor="3",
            num_before=2,
            num_after=2
        )

        # then
        self.assertEqual(len(result), 0)

    async def test_get_stream_messages_all_messages_filtered(self):
        # given
        current_time = datetime.now(timezone.utc)
        from app.models.message import MessageType

        # 모든 메시지가 user_oldest_message보다 이전인 경우
        mock_messages = [
            MessageBase(
                id=1,
                sender_id=1,
                type=MessageType.NORMAL,
                recipient_id=1,
                content="Message 1",
                rendered_content="<p>Message 1</p>",
                date_sent=current_time,
                has_attachment=False,
                has_image=False,
                has_link=False
            ),
            MessageBase(
                id=2,
                sender_id=1,
                type=MessageType.NORMAL,
                recipient_id=1,
                content="Message 2",
                rendered_content="<p>Message 2</p>",
                date_sent=current_time,
                has_attachment=False,
                has_image=False,
                has_link=False
            )
        ]

        mock_oldest_message = MessageBase(
            id=5,  # 모든 메시지보다 더 큰 ID
            sender_id=1,
            type=MessageType.NORMAL,
            recipient_id=1,
            content="Message 5",
            rendered_content="<p>Message 5</p>",
            date_sent=current_time,
            has_attachment=False,
            has_image=False,
            has_link=False
        )

        self.service._check_stream_permission = AsyncMock(return_value=True)
        self.service._convert_anchor_to_id = AsyncMock(return_value=2)
        self.message_crud.get_stream_messages = AsyncMock(return_value=mock_messages)
        self.user_message_crud.get_oldest_message_in_stream = AsyncMock(
            return_value=mock_oldest_message)

        # when
        result = await self.service.get_stream_messages(
            db=self.db,
            user_id=1,
            stream_id=1,
            anchor="2",
            num_before=1,
            num_after=1
        )

        # then
        self.assertEqual(len(result), 0)  # 모든 메시지가 필터링되어야 함

    async def test_get_stream_messages_oldest_message_at_start(self):
        # given
        current_time = datetime.now(timezone.utc)
        from app.models.message import MessageType

        mock_messages = [
            MessageBase(
                id=1,
                sender_id=1,
                type=MessageType.NORMAL,
                recipient_id=1,
                content="Message 1",
                rendered_content="<p>Message 1</p>",
                date_sent=current_time,
                has_attachment=False,
                has_image=False,
                has_link=False
            ),
            MessageBase(
                id=2,
                sender_id=1,
                type=MessageType.NORMAL,
                recipient_id=1,
                content="Message 2",
                rendered_content="<p>Message 2</p>",
                date_sent=current_time,
                has_attachment=False,
                has_image=False,
                has_link=False
            )
        ]

        mock_oldest_message = MessageBase(
            id=1,  # 첫 번째 메시지와 동일한 ID
            sender_id=1,
            type=MessageType.NORMAL,
            recipient_id=1,
            content="Message 1",
            rendered_content="<p>Message 1</p>",
            date_sent=current_time,
            has_attachment=False,
            has_image=False,
            has_link=False
        )

        self.service._check_stream_permission = AsyncMock(return_value=True)
        self.service._convert_anchor_to_id = AsyncMock(return_value=1)
        self.message_crud.get_stream_messages = AsyncMock(return_value=mock_messages)
        self.user_message_crud.get_oldest_message_in_stream = AsyncMock(
            return_value=mock_oldest_message)

        # when
        result = await self.service.get_stream_messages(
            db=self.db,
            user_id=1,
            stream_id=1,
            anchor="1",
            num_before=1,
            num_after=1
        )

        # then
        self.assertEqual(len(result), 2)  # 모든 메시지가 포함되어야 함
        self.assertEqual(result[0].id, 1)
        self.assertEqual(result[1].id, 2)