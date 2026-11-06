from types import SimpleNamespace
from unittest import IsolatedAsyncioTestCase
from unittest.mock import AsyncMock

from fastapi_users.password import PasswordHelper
from httpx import ASGITransport, AsyncClient
from sqlalchemy import func, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.core.db import get_async_session
from app.core.security import current_active_user
from app.domains.randomchat.schemas import QueueStatus
from app.domains.randomchat.service import (
    RandomChatService,
    get_random_chat_service,
)
from app.main import app
from app.models import Stream, User
from app.tests.conftest import BaseTest, test_engine


QUEUE_PATH = "/api/v1/random/match/queue"
JOIN_PATH = f"{QUEUE_PATH}/join"
LEAVE_PATH = f"{QUEUE_PATH}/leave"

ProductionLikeSessionLocal = async_sessionmaker(
    bind=test_engine, expire_on_commit=False
)


async def override_production_like_db():
    async with ProductionLikeSessionLocal() as session:
        yield session


class TestRandomChatRoutes(IsolatedAsyncioTestCase):
    def setUp(self):
        app.dependency_overrides.clear()
        self.user = SimpleNamespace(id=17, is_active=True, is_verified=True)
        self.service = AsyncMock(spec=RandomChatService)

    def tearDown(self):
        app.dependency_overrides.clear()

    async def request(self, method: str, path: str):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            return await client.request(method, path)

    def authenticate(self):
        app.dependency_overrides[current_active_user] = lambda: self.user
        app.dependency_overrides[get_random_chat_service] = lambda: self.service

    async def test_queue_routes_require_authentication(self):
        for method, path in (
            ("POST", JOIN_PATH),
            ("POST", LEAVE_PATH),
            ("GET", QUEUE_PATH),
        ):
            with self.subTest(path=path):
                response = await self.request(method, path)
                self.assertEqual(response.status_code, 401)

        self.service.join.assert_not_awaited()
        self.service.leave.assert_not_awaited()
        self.service.status.assert_not_awaited()

    async def test_join_returns_waiting_state(self):
        self.authenticate()
        self.service.join.return_value = QueueStatus(
            status="waiting", stream_id=None
        )

        response = await self.request("POST", JOIN_PATH)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(), {"status": "waiting", "stream_id": None}
        )
        self.assertEqual(response.headers["cache-control"], "no-store")
        self.service.join.assert_awaited_once()
        _, user_id = self.service.join.await_args.args
        self.assertEqual(user_id, self.user.id)

    async def test_status_and_leave_return_the_service_result(self):
        self.authenticate()
        self.service.status.return_value = QueueStatus(
            status="matched", stream_id=42
        )
        self.service.leave.return_value = QueueStatus(
            status="matched", stream_id=42
        )

        status_response = await self.request("GET", QUEUE_PATH)
        leave_response = await self.request("POST", LEAVE_PATH)

        for response in (status_response, leave_response):
            self.assertEqual(response.status_code, 200)
            self.assertEqual(
                response.json(), {"status": "matched", "stream_id": 42}
            )
        self.service.status.assert_awaited_once()
        self.service.leave.assert_awaited_once()

    async def test_storage_failure_is_an_explicit_temporary_error(self):
        self.authenticate()
        self.service.join.side_effect = SQLAlchemyError("private db detail")

        response = await self.request("POST", JOIN_PATH)

        self.assertEqual(response.status_code, 503)
        payload = response.json()
        self.assertEqual(
            payload["detail"]["code"], "random_chat_unavailable"
        )
        self.assertNotIn("private db detail", response.text)
        self.assertEqual(response.headers["cache-control"], "no-store")

    async def test_join_rejects_an_ineligible_account(self):
        self.authenticate()
        self.service.join.side_effect = PermissionError("private eligibility detail")

        response = await self.request("POST", JOIN_PATH)

        self.assertEqual(response.status_code, 403)
        self.assertNotIn("private eligibility detail", response.text)
        self.assertEqual(response.headers["cache-control"], "no-store")

    def test_openapi_describes_all_queue_results(self):
        schema = app.openapi()

        for method, path in (
            ("post", JOIN_PATH),
            ("post", LEAVE_PATH),
            ("get", QUEUE_PATH),
        ):
            responses = schema["paths"][path][method]["responses"]
            self.assertIn("200", responses)
            self.assertIn("503", responses)
            self.assertEqual(
                responses["200"]["content"]["application/json"]["schema"],
                {"$ref": "#/components/schemas/QueueStatus"},
            )

        status_schema = schema["components"]["schemas"]["QueueStatus"]
        self.assertEqual(
            set(status_schema["properties"]["status"]["enum"]),
            {"idle", "waiting", "matched"},
        )


class TestRandomChatAuthenticatedFlow(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()
        password = "random-chat-password"
        hashed_password = PasswordHelper().hash(password)
        self.password = password
        self.users = [
            User(
                email=f"random-flow-{index}@example.com",
                hashed_password=hashed_password,
                name=f"Random Flow User {index}",
                gender="male",
                is_active=True,
                is_superuser=False,
                is_verified=True,
            )
            for index in range(3)
        ]
        self.db.add_all(self.users)
        await self.db.flush()
        self.user_ids = [user.id for user in self.users]
        self.user_emails = [user.email for user in self.users]
        await self.db.commit()
        app.dependency_overrides[get_async_session] = override_production_like_db

    async def login(self, client: AsyncClient, email: str) -> dict[str, str]:
        response = await client.post(
            "/api/v1/auth/login",
            data={"username": email, "password": self.password},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return {"Authorization": f"Bearer {response.json()['access_token']}"}

    async def test_two_logged_in_users_match_and_can_exchange_a_message(self):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            first_headers = await self.login(client, self.user_emails[0])
            second_headers = await self.login(client, self.user_emails[1])
            outsider_headers = await self.login(client, self.user_emails[2])

            direct_stream = await client.post(
                "/api/v1/stream/create",
                headers=outsider_headers,
                json={"name": "bypass", "type": "random"},
            )
            direct_meet_post = await client.post(
                "/api/v1/meet_post/create",
                headers=outsider_headers,
                json={
                    "title": "bypass",
                    "type": "random",
                    "content": "must be rejected",
                    "max_people": 2,
                },
            )
            self.assertEqual(direct_stream.status_code, 422)
            self.assertEqual(direct_meet_post.status_code, 422)
            room_count = await self.db.scalar(
                select(func.count()).select_from(Stream)
            )
            self.assertEqual(room_count, 0)

            first_join = await client.post(JOIN_PATH, headers=first_headers)
            second_join = await client.post(JOIN_PATH, headers=second_headers)

            self.assertEqual(first_join.status_code, 200, first_join.text)
            self.assertEqual(first_join.json()["status"], "waiting")
            self.assertEqual(second_join.status_code, 200, second_join.text)
            self.assertEqual(second_join.json()["status"], "matched")
            stream_id = second_join.json()["stream_id"]

            first_status = await client.get(QUEUE_PATH, headers=first_headers)
            self.assertEqual(
                first_status.json(), {"status": "matched", "stream_id": stream_id}
            )
            participant_location = await client.post(
                f"/api/v1/messages/send/stream/location/{stream_id}",
                headers=first_headers,
                json={"lat": 36.7365, "lng": 127.0751},
            )
            self.assertEqual(
                participant_location.status_code, 200, participant_location.text
            )
            outsider_location = await client.post(
                f"/api/v1/messages/send/stream/location/{stream_id}",
                headers=outsider_headers,
                json={"lat": 36.7365, "lng": 127.0751},
            )
            self.assertEqual(outsider_location.status_code, 403)
            send = await client.post(
                f"/api/v1/messages/send/stream/{stream_id}",
                headers=first_headers,
                data={"message_content": "random chat integration"},
            )
            self.assertEqual(send.status_code, 200, send.text)
            messages = await client.get(
                "/api/v1/messages/stream",
                headers=second_headers,
                params={"stream_id": stream_id},
            )
            self.assertEqual(messages.status_code, 200, messages.text)
            self.assertTrue(
                any(
                    message["content"] == "random chat integration"
                    for message in messages.json()
                )
            )

            outsider_subscribe = await client.post(
                "/api/v1/users/me/subscriptions",
                headers=outsider_headers,
                json={"stream_id": stream_id},
            )
            self.assertEqual(outsider_subscribe.status_code, 403)

            unsubscribe = await client.request(
                "DELETE",
                "/api/v1/users/me/subscriptions",
                headers=first_headers,
                json={"stream_id": stream_id},
            )
            self.assertEqual(unsubscribe.status_code, 200, unsubscribe.text)
            reactivate = await client.post(
                "/api/v1/users/me/subscriptions",
                headers=first_headers,
                json={"stream_id": stream_id},
            )
            self.assertEqual(reactivate.status_code, 403)
