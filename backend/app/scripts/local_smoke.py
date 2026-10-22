"""Exercise synthetic local accounts through the running API; never log tokens."""
import asyncio
from io import BytesIO
import logging
import os
import uuid
from urllib.parse import urlsplit

import httpx
from PIL import Image
from websockets import connect

from app.core.config import settings


async def main():
    logging.disable(logging.CRITICAL)
    base = os.environ.get("SMOKE_BASE_URL", "http://web:8000")
    async with httpx.AsyncClient(base_url=base, timeout=20) as client:
        def ok(response, status=200):
            if response.status_code != status:
                raise AssertionError(f"HTTP {response.status_code} (expected {status})")
            return response.json() if response.content else None

        tokens = ok(await client.post('/api/v1/auth/login', data={
            'username': settings.FIRST_SUPERUSER, 'password': settings.FIRST_SUPERUSER_PASSWORD}))
        tokens = ok(await client.post('/api/v1/auth/refresh', json={'refresh_token': tokens['refresh_token']}))
        headers = {'Authorization': 'Bearer ' + tokens['access_token']}
        ok(await client.get('/api/v1/admin/user/list', headers=headers))
        member = ok(await client.post('/api/v1/auth/login', data={
            'username': 'member@example.com', 'password': settings.FIRST_SUPERUSER_PASSWORD}))
        member_headers = {'Authorization': 'Bearer ' + member['access_token']}
        assert (await client.get('/api/v1/admin/user/list', headers=member_headers)).status_code == 403
        old_profile = ok(await client.get('/api/v1/auth/me', headers=headers)).get('profile')
        post = ok(await client.post('/api/v1/meet_post/create', headers=headers, json={
            'title': 'smoke-' + uuid.uuid4().hex[:8], 'type': 'meet',
            'content': 'Synthetic local test', 'max_people': 3}))
        stream_id = post['stream_id']
        ok(await client.post(f'/api/v1/stream/{stream_id}/active', headers=headers))
        path = '/api/v1/events/connect?last_event_id=0-0'
        async with connect(base.replace('http', 'ws', 1) + path,
                           subprotocols=[tokens['access_token']]) as ws:
            ok(await client.post(f'/api/v1/messages/send/stream/{stream_id}',
                                 headers=headers, data={'message_content': 'Local hello'}))
            event = await asyncio.wait_for(ws.recv(), timeout=10)
            if 'Local hello' not in event:
                raise AssertionError('Chat event payload missing')
        messages = ok(await client.get('/api/v1/messages/stream', headers=headers,
                                       params={'stream_id': stream_id}))
        assert any(m['content'] == 'Local hello' for m in messages)
        image = BytesIO()
        Image.new('RGB', (8, 8), 'blue').save(image, format='PNG')
        profile = ok(await client.post('/api/v1/users/me/profile', headers=headers,
                                      files={'file': ('test.png', image.getvalue(), 'image/png')}))
        parsed = urlsplit(profile['profile_url'])
        response = await client.get(parsed.path + '?' + parsed.query)
        assert response.status_code == 200 and response.content == image.getvalue()
        assert (await client.get(parsed.path)).status_code == 403
        if old_profile:
            previous = urlsplit(old_profile)
            assert (await client.get(previous.path + '?' + previous.query)).status_code == 404
        assert (await client.get('/api/v1/auth/me')).status_code == 401
        print('PASS: login, refresh, admin authorization, post, chat HTTP/WS, image upload/read/delete/signature')


if __name__ == '__main__':
    asyncio.run(main())
