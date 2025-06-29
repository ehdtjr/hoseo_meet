from typing import Protocol, List, Tuple, Optional

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import redis_client
from app.schemas.stream import StreamCreate
from app.service.stream import StreamService, get_stream_service, SubscriberService, get_subscription_service


class RandomChatWaitingRoomProtocol(Protocol):
    async def join(self, user_id: int):
        ...

    async def leave(self, user_id: int):
        ...

    async def list(self) -> List[int]:
        ...

    async def length(self) -> int:
        ...


class RedisRandomChatWaitingRoom(RandomChatWaitingRoomProtocol):
    async def join(self, user_id: int):
        await redis_client.lpush("waiting_room", user_id)

    async def leave(self, user_id: int):
        await redis_client.lrem("waiting_room", 0, user_id)

    async def list(self) -> List[int]:
        user_ids = await redis_client.lrange("waiting_room", 0, -1)
        return [int(u) for u in user_ids]

    async def length(self) -> int:
        return await redis_client.llen("waiting_room")


def get_random_chat_waiting_room() -> RandomChatWaitingRoomProtocol:
    return RedisRandomChatWaitingRoom()


class RandomChatMatcherProtocol(Protocol):
    async def match_pair(
        self, waiting_room: RandomChatWaitingRoomProtocol
    ) -> Optional[Tuple[int, int]]:
        ...


class RandomChatFIFOQueueMatcher(RandomChatMatcherProtocol):
    async def match_pair(
        self, waiting_room: RandomChatWaitingRoomProtocol
    ) -> Optional[Tuple[int, int]]:
        """
        Redis Lua 스크립트: 대기열에서 두 명을 원자적으로 pop.
        """
        lua_script = """
        local user1 = redis.call('rpop', KEYS[1])
        if not user1 then return nil end
        local user2 = redis.call('rpop', KEYS[1])
        if not user2 then
            redis.call('rpush', KEYS[1], user1)
            return nil
        end
        return {user1, user2}
        """
        result = await (redis_client.eval(lua_script, keys=["waiting_room"]))
        if result and len(result) == 2:
            return int(result[0]), int(result[1])
        return None


def get_random_chat_fifo_queue_matcher() -> RandomChatFIFOQueueMatcher:
    return RandomChatFIFOQueueMatcher()


class RandomChatServiceProtocol(Protocol):
    async def join(self, db: AsyncSession, user_id: int):
        ...

    async def leave(self, user_id: int):
        ...


class BasicRandomChatService(RandomChatServiceProtocol):
    def __init__(
        self,
        random_chat_waiting_room: RandomChatWaitingRoomProtocol,
        random_chat_matcher: RandomChatMatcherProtocol,
        stream_service: StreamService,
        subscriber_service: SubscriberService,
    ):
        self.waiting_room = random_chat_waiting_room
        self.matcher = random_chat_matcher
        self.stream_service = stream_service
        self.subscriber_service = subscriber_service

    async def join(self, db: AsyncSession, user_id: int):
        await self.waiting_room.join(user_id)

        # ✅ 길이 먼저 확인
        if await self.waiting_room.length() < 2:
            return

        # ✅ 원자적 매칭 시도
        pair = await self.matcher.match_pair(self.waiting_room)
        if not pair:
            return  # 다른 프로세스가 이미 가져갔음

        user1, user2 = pair

        # ✅ 방 생성 (익명 랜덤 채팅)
        create_stream_data = StreamCreate(
            name="익명 랜덤 채팅!",
            type="random",
            creator_id=user1,
        )
        created_stream = await self.stream_service.create_stream(
            db=db, stream_create=create_stream_data
        )

        # ✅ 방 구독
        await self.subscriber_service.subscribe(db, user_id=user1, stream_id=created_stream.stream_id)
        await self.subscriber_service.subscribe(db, user_id=user2, stream_id=created_stream.stream_id)

    async def leave(self, user_id: int):
        await self.waiting_room.leave(user_id)


def get_basic_random_chat_service(
    random_chat_waiting_room: RandomChatWaitingRoomProtocol = Depends(get_random_chat_waiting_room),
    random_chat_matcher: RandomChatMatcherProtocol = Depends(get_random_chat_fifo_queue_matcher),
    stream_service: StreamService = Depends(get_stream_service),
    subscriber_service: SubscriberService = Depends(get_subscription_service),
) -> RandomChatServiceProtocol:
    return BasicRandomChatService(
        random_chat_waiting_room=random_chat_waiting_room,
        random_chat_matcher=random_chat_matcher,
        stream_service=stream_service,
        subscriber_service=subscriber_service,
    )
