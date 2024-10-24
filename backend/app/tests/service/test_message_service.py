from datetime import datetime
from unittest.mock import AsyncMock

from app.core.exceptions import PermissionDeniedException
from app.models import Recipient, Stream, User
from app.schemas.message import UserMessageBase
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