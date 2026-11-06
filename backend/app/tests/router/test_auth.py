"""Exercise real Bearer dependencies, user lookup and Redis with synthetic accounts."""

from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import jwt
from fastapi_users.password import PasswordHelper
from httpx import ASGITransport, AsyncClient

from app.core.security import get_custom_jwt_strategy, get_redis_token_storage
from app.main import app
from app.models.user import User
from app.tests.conftest import BaseTest


class TestTokenPurpose(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()
        self.password = "synthetic-auth-test-password"
        self.user = User(
            email="auth-purpose@example.com",
            hashed_password=PasswordHelper().hash(self.password),
            name="Synthetic user",
            gender="기타",
            is_active=True,
            is_verified=True,
            is_superuser=False,
        )
        self.db.add(self.user)
        await self.db.commit()
        await self.db.refresh(self.user)
        self.storage = await get_redis_token_storage()
        self.strategy = await get_custom_jwt_strategy(self.storage)
        self.tokens = await self.strategy.write_token(self.user)
        self.client = AsyncClient(transport=ASGITransport(app=app), base_url="http://test")

    async def asyncTearDown(self):
        await self.client.aclose()
        await super().asyncTearDown()

    def headers(self, token):
        return {"Authorization": f"Bearer {token}"}

    def signed_token(self, token_type, updates=None, missing=None, secret=None):
        payload = {
            "sub": str(self.user.id),
            "exp": datetime.now(timezone.utc) + timedelta(hours=1),
            "aud": self.strategy.token_audience,
            "type": token_type,
        }
        payload.update(updates or {})
        if missing:
            del payload[missing]
        return jwt.encode(payload, secret or self.strategy.encode_key, algorithm="HS256")

    async def refresh(self, token):
        return await self.client.post("/api/v1/auth/refresh", json={"refresh_token": token})

    async def test_login_and_access_authentication(self):
        response = await self.client.post(
            "/api/v1/auth/login",
            data={"username": self.user.email, "password": self.password},
        )
        self.assertEqual(response.status_code, 200)
        tokens = response.json()
        response = await self.client.get(
            "/api/v1/auth/me", headers=self.headers(tokens["access_token"])
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["id"], self.user.id)
        self.assertEqual((await self.refresh(tokens["refresh_token"])).status_code, 200)

    async def test_refresh_cannot_authenticate_or_logout(self):
        headers = self.headers(self.tokens["refresh_token"])
        response = await self.client.get("/api/v1/auth/me", headers=headers)
        self.assertEqual(response.status_code, 401)
        response = await self.client.post("/api/v1/auth/logout", headers=headers)
        self.assertEqual(response.status_code, 401)
        # Rejected logout must not revoke the valid refresh session.
        self.assertEqual((await self.refresh(self.tokens["refresh_token"])).status_code, 200)

    async def test_missing_bearer_is_rejected(self):
        self.assertEqual((await self.client.get("/api/v1/auth/me")).status_code, 401)

    async def test_unknown_access_subject_is_rejected(self):
        token = self.signed_token("access", {"sub": str(self.user.id + 1000)})
        response = await self.client.get("/api/v1/auth/me", headers=self.headers(token))
        self.assertEqual(response.status_code, 401)

    async def test_access_cannot_refresh_even_if_stored(self):
        token = self.tokens["access_token"]
        await self.storage.store_token(str(self.user.id), token, 3600)
        self.assertEqual((await self.refresh(token)).status_code, 400)

    def invalid_tokens(self, token_type):
        yield "expired", self.signed_token(token_type, {"exp": 1})
        yield "tampered", self.signed_token(token_type, secret="different-synthetic-key")
        yield "audience", self.signed_token(token_type, {"aud": ["another-service"]})
        yield "type", self.signed_token(token_type, {"type": "verification"})
        yield "empty subject", self.signed_token(token_type, {"sub": ""})
        yield "numeric subject", self.signed_token(token_type, {"sub": self.user.id})
        yield "invalid subject", self.signed_token(token_type, {"sub": "not-an-id"})
        yield "malformed", "synthetic.invalid.jwt"
        for claim in ("sub", "exp", "aud", "type"):
            yield f"missing {claim}", self.signed_token(token_type, missing=claim)

    async def test_invalid_access_is_rejected_by_http_authentication(self):
        for case, token in self.invalid_tokens("access"):
            with self.subTest(case=case):
                response = await self.client.get(
                    "/api/v1/auth/me", headers=self.headers(token)
                )
                self.assertEqual(response.status_code, 401)

    async def test_invalid_refresh_is_rejected_even_if_stored(self):
        for case, token in self.invalid_tokens("refresh"):
            with self.subTest(case=case):
                await self.storage.store_token(str(self.user.id), token, 3600)
                self.assertEqual((await self.refresh(token)).status_code, 400)

    async def test_revoked_refresh_is_rejected(self):
        await self.storage.delete_token(str(self.user.id))
        self.assertEqual((await self.refresh(self.tokens["refresh_token"])).status_code, 400)

    async def test_refresh_rotates_even_within_the_same_second(self):
        fixed_time = datetime.now(timezone.utc)
        with patch("app.service.auth.datetime") as clock:
            clock.now.return_value = fixed_time
            first = await self.strategy.write_token(self.user)
            response = await self.refresh(first["refresh_token"])
            self.assertEqual(response.status_code, 200)
            second = response.json()
            self.assertNotEqual(first["refresh_token"], second["refresh_token"])
            self.assertEqual((await self.refresh(first["refresh_token"])).status_code, 400)
            self.assertEqual((await self.refresh(second["refresh_token"])).status_code, 200)

    async def test_logout_revokes_refresh_but_access_lasts_until_expiry(self):
        headers = self.headers(self.tokens["access_token"])
        response = await self.client.post("/api/v1/auth/logout", headers=headers)
        self.assertEqual(response.status_code, 200)
        self.assertIsNone(await self.storage.read_token(str(self.user.id)))
        self.assertEqual((await self.refresh(self.tokens["refresh_token"])).status_code, 400)
        self.assertEqual(
            (await self.client.get("/api/v1/auth/me", headers=headers)).status_code, 200
        )

    async def test_second_login_replaces_account_refresh_session(self):
        response = await self.client.post(
            "/api/v1/auth/login",
            data={"username": self.user.email, "password": self.password},
        )
        self.assertEqual(response.status_code, 200)
        second = response.json()
        self.assertNotEqual(self.tokens["refresh_token"], second["refresh_token"])
        self.assertEqual((await self.refresh(self.tokens["refresh_token"])).status_code, 400)
        self.assertEqual((await self.refresh(second["refresh_token"])).status_code, 200)
        # Any device's still-valid access token logs out the account's refresh session.
        response = await self.client.post(
            "/api/v1/auth/logout", headers=self.headers(self.tokens["access_token"])
        )
        self.assertEqual(response.status_code, 200)
        self.assertIsNone(await self.storage.read_token(str(self.user.id)))

    async def test_existing_tokens_without_jti_remain_compatible(self):
        access = self.signed_token("access")
        refresh = self.signed_token("refresh")
        await self.storage.store_token(str(self.user.id), refresh, 3600)
        response = await self.client.get("/api/v1/auth/me", headers=self.headers(access))
        self.assertEqual(response.status_code, 200)
        self.assertEqual((await self.refresh(refresh)).status_code, 200)

    async def test_inactive_user_is_rejected(self):
        self.user.is_active = False
        await self.db.commit()
        response = await self.client.get(
            "/api/v1/auth/me", headers=self.headers(self.tokens["access_token"])
        )
        self.assertEqual(response.status_code, 401)
        self.assertEqual((await self.refresh(self.tokens["refresh_token"])).status_code, 400)
