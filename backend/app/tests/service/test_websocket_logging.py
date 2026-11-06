"""Synthetic-only log captures; no DB, Redis server or external clients needed."""
import asyncio
import json
import logging
from unittest import IsolatedAsyncioTestCase
from unittest.mock import AsyncMock, Mock, patch

from aioredis.exceptions import ConnectionError as ServerConnectionError
from starlette.websockets import WebSocketDisconnect

from app.service.websocket.websocket_handler import WebSocketEventHandler

MARKERS = ("PRIVATE_CHAT_24", "37.123456789", "127.987654321", "TOKEN_24")
PRIVATE_TEXT = " ".join(MARKERS)
LOGGER = "app.service.websocket.websocket_handler"


class TestWebSocketLogging(IsolatedAsyncioTestCase):
    def setUp(self):
        self.manager = Mock(connect=AsyncMock(), send_message=AsyncMock())
        self.handler = WebSocketEventHandler(self.manager)
        self.websocket = Mock(query_params={"last_event_id": PRIVATE_TEXT})

    def check_capture(self, capture, *statuses):
        output = "\n".join(capture.output)
        for marker in MARKERS:
            self.assertNotIn(marker, output)
        for status in statuses:
            self.assertIn(status, output)

    async def test_forward_events_unchanged_with_safe_type_logs(self):
        with self.assertLogs(LOGGER, level=logging.DEBUG) as capture:
            for event_type in ("stream", "location", "read", "user", PRIVATE_TEXT, [PRIVATE_TEXT]):
                payload = {"content": MARKERS[0], "lat": 37.123456789,
                           "lng": 127.987654321, "token": MARKERS[3]}
                event = {"type": event_type, "data": json.dumps(payload)}
                await self.handler._process_and_send_events(
                    [(PRIVATE_TEXT, [(PRIVATE_TEXT, event)])], self.websocket)
                sent = self.manager.send_message.call_args.args[0]
                self.assertEqual(json.loads(sent), {
                    "type": event_type, "data": payload, "last_event_id": PRIVATE_TEXT})
        self.check_capture(capture, "event_sent type=stream", "event_sent type=location",
                           "event_sent type=read", "event_sent type=user", "event_sent type=unknown")

    async def test_parse_and_send_errors_do_not_quote_input(self):
        self.manager.send_message.side_effect = RuntimeError(PRIVATE_TEXT)
        with self.assertLogs(LOGGER, level=logging.DEBUG) as capture:
            await self.handler._send_event(self.websocket, PRIVATE_TEXT,
                                           {"type": PRIVATE_TEXT, "data": PRIVATE_TEXT})
        # Preserve the existing malformed-data fallback while reporting the failure.
        sent = self.manager.send_message.call_args.args[0]
        self.assertEqual(json.loads(sent)["data"], PRIVATE_TEXT)
        self.check_capture(capture, "decode_failed type=unknown", "send_failed type=unknown")

    async def test_client_frames_and_close_reasons_are_private(self):
        for error, status in ((WebSocketDisconnect(1000, PRIVATE_TEXT), "client_disconnected"),
                              (RuntimeError(PRIVATE_TEXT), "receive_failed")):
            with self.subTest(status=status):
                self.websocket.receive_text = AsyncMock(side_effect=[PRIVATE_TEXT, error])
                disconnected = asyncio.Event()
                with self.assertLogs(LOGGER, level=logging.DEBUG) as capture:
                    with self.assertRaises(type(error)):
                        await self.handler._receive_ws_messages(self.websocket, disconnected)
                self.assertTrue(disconnected.is_set())
                self.check_capture(capture, "client_frame_received", status)

    async def test_redis_failures_are_diagnosable_without_exception_text(self):
        for error, status in ((WebSocketDisconnect(1000, PRIVATE_TEXT), "redis_forwarding_disconnected"),
                              (ServerConnectionError(PRIVATE_TEXT), "redis_connection_failed"),
                              (RuntimeError(PRIVATE_TEXT), "redis_forwarding_failed")):
            with self.subTest(status=status):
                pool = Mock(xread=AsyncMock(side_effect=error))
                disconnected = asyncio.Event()
                with patch("app.service.websocket.websocket_handler.redis_client.redis", pool):
                    with self.assertLogs(LOGGER, level=logging.DEBUG) as capture:
                        with self.assertRaises(type(error)):
                            await self.handler._receive_from_redis(self.websocket, PRIVATE_TEXT, disconnected)
                self.assertTrue(disconnected.is_set())
                self.check_capture(capture, status)

    async def test_connection_failure_is_sanitized_and_cleanup_runs(self):
        self.handler._receive_from_redis = AsyncMock(side_effect=RuntimeError(PRIVATE_TEXT))
        self.handler._receive_ws_messages = AsyncMock()
        with self.assertLogs(LOGGER, level=logging.DEBUG) as capture:
            await self.handler.handle_connection(self.websocket, 1, asyncio.Event())
        self.manager.disconnect.assert_called_once_with(self.websocket)
        self.check_capture(capture, "connection_failed", "disconnected")
