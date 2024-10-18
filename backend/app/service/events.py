import asyncio
import json
import logging

from aioredis import Redis
from pyfcm import FCMNotification
from sqlmodel.ext.asyncio.session import AsyncSession

from app.crud.user_crud import get_user_fcm_token_crud
from app.schemas.user import UserFCMTokenBase, UserRead

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

fcm = FCMNotification(service_account_file="hoseo-meet-firebase-adminsdk"
"-oswm2-1186906f2e.json", project_id="hoseo-meet")

class SendEventProtocol:
    async def send(self, event_data: dict):
        pass

class SendEventWebsocket(SendEventProtocol):
    def __init__(self, redis: Redis, user_id: int):
        self.redis = redis
        self.user_id = user_id

    async def send(self, event_data: dict):
        logger.info(f"Sent Websocket event to user {self.user_id}")
        if not event_data:
            raise ValueError("Event data is empty or invalid")

        event_data_json = json.dumps(event_data, ensure_ascii=False)
        await self.redis.xadd(f"queue:{self.user_id}", {"data": event_data_json})

class SendEventFCM(SendEventProtocol):
    def __init__(self, user_id: int, fcm_token: str):
        self.user_id = user_id
        self.fcm_token = fcm_token

    async def send(self, event_data: dict):
        if not self.fcm_token:
            logger.error(f"No FCM token available for user {self.user_id}")
            return
        await asyncio.to_thread(self._send_fcm_notification, event_data,
        self.fcm_token)

    def _send_fcm_notification(self, event_data: dict, fcm_token: str):
        fcm.notify(
            fcm_token=fcm_token,
            notification_title = "New message",
            notification_body = json.dumps(event_data, ensure_ascii=False)
        )

class SendEventManager:
    def __init__(self, sender: SendEventProtocol):
        self.sender = sender

    async def send_event(self, event_data: dict):
        await self.sender.send(event_data)

async def create_send_event_manager(
        db: AsyncSession,
        redis: Redis,
        user: UserRead
) -> SendEventManager:
    if user.is_online:
        sender = SendEventWebsocket(redis, user.id)
    else:
        user_fcm_crud = get_user_fcm_token_crud()
        user_fcm_data: UserFCMTokenBase = await user_fcm_crud.get_user_fcm_token_by_user_id(db, user.id)

        fcm_token = user_fcm_data.fcm_token if user_fcm_data else None
        sender = SendEventFCM(user.id, fcm_token)

    return SendEventManager(sender)
