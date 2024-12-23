from app.schemas.event import EventBase
from app.service.event.events import WebSocketEventSender
from app.tests.conftest import BaseTest

class TestWebSocketEventSender(BaseTest):
    async def test_send_event(self):
        sender = WebSocketEventSender()
        user_id = 1

        # EventBase 인스턴스를 생성하여 이벤트 데이터로 사용
        event_data = EventBase(
            type="stream",
            data={
                "event": "message",
                "content": "Hello, World!"
            }
        )

        # 이벤트 전송
        await sender.send_event(user_id, event_data)

        # Redis에서 데이터 확인
        events = await self.redis_client.xrange(f"queue:{user_id}")

        # 데이터가 올바르게 저장되었는지 확인
        assert len(events) == 1, "이벤트가 Redis 스트림에 저장되지 않았습니다."
        event_id, stored_data = events[0]

        # 저장된 데이터가 원본 이벤트 데이터와 일치하는지 확인
        expected_data = event_data.to_str_dict()
        assert stored_data == expected_data, "저장된 데이터가 원본 이벤트 데이터와 일치하지 않습니다."
