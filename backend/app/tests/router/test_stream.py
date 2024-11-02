from httpx import ASGITransport, AsyncClient

from app.core.db import get_async_session
from app.core.security import current_active_user
from app.main import app
from app.models import User
from app.tests.conftest import BaseTest, override_get_db


class TestCreateStream(BaseTest):

    async def asyncSetUp(self):
        await super().asyncSetUp()

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

    async def asyncTearDown(self):
        await super().asyncTearDown()

    async def override_current_user(self):
        return self.user

    async def test_create_stream(self):
        async with AsyncClient(
                transport=ASGITransport(app=app), base_url="http://test"
        ) as ac:
            app.dependency_overrides[
                current_active_user] = self.override_current_user
            app.dependency_overrides[get_async_session] = override_get_db

            stream_data = {"name": "Test Stream", "type": "happy"}
            response = await ac.post("/api/v1/stream/create",
                                     json=stream_data)

            assert response.status_code == 200
            assert response.json()["name"] == "Test Stream"
            assert response.json()["type"] == "happy"
            assert response.json()["creator_id"] == self.user.id

        app.dependency_overrides = {}
