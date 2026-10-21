from unittest.mock import AsyncMock, patch
from httpx import ASGITransport, AsyncClient

from app.core.db import get_async_session
from app.core.security import current_active_user
from app.main import app
from app.models import User
from app.tests.conftest import BaseTest, override_get_db


class TestCreateStream(BaseTest):

    async def asyncSetUp(self):
        await super().asyncSetUp()

        # 사용자 생성
        user_data = {
            "email": "testuser@example.com",
            "hashed_password": "hashedpassword",
            "name": "Test User",
            "gender": "male",
            "is_active": True,
            "is_superuser": False,
            "is_verified": True,
        }
        self.user = User(**user_data)
        self.db.add(self.user)
        await self.db.commit()
        await self.db.refresh(self.user)

        app.dependency_overrides = {}

    async def asyncTearDown(self):
        await super().asyncTearDown()

    async def override_current_user(self):
        return self.user

    async def test_create_stream(self):
        async with AsyncClient(
                transport=ASGITransport(app=app), base_url="http://test"
        ) as ac:
            app.dependency_overrides[current_active_user] = self.override_current_user
            app.dependency_overrides[get_async_session] = override_get_db

            stream_data = {"name": "Test Stream", "type": "meet"}
            response = await ac.post("/api/v1/stream/create", json=stream_data)

            assert response.status_code == 201
            json_data = response.json()
            assert json_data["name"] == "Test Stream"
            assert json_data["type"] == "meet"
            assert json_data["creator_id"] == self.user.id

        app.dependency_overrides = {}

    async def test_active_stream(self):
        async with AsyncClient(
                transport=ASGITransport(app=app), base_url="http://test"
        ) as ac:
            created_stream_id = 1
            app.dependency_overrides[current_active_user] = self.override_current_user
            app.dependency_overrides[get_async_session] = override_get_db

            active_response = await ac.post(f"/api/v1/stream/{created_stream_id}/active")
            assert active_response.status_code == 200
            assert active_response.json() == {"detail": "Stream activated"}

        app.dependency_overrides = {}

    async def test_clear_active_stream_mocked(self):
        async with AsyncClient(
                transport=ASGITransport(app=app), base_url="http://test"
        ) as ac:
            app.dependency_overrides[current_active_user] = self.override_current_user
            app.dependency_overrides[get_async_session] = override_get_db
            created_stream_id = 1

            active_clear_response = await ac.post(f"/api/v1/stream/"
            f"deactive")

            assert active_clear_response.status_code == 200
            assert active_clear_response.json() == {"detail": "Stream deactivated"}
            app.dependency_overrides = {}
