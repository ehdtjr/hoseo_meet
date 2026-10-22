from unittest import IsolatedAsyncioTestCase
from unittest.mock import AsyncMock, patch

from fastapi_mail import MessageType
from app.celery.event_email_task import _send_email


class TestSendEmail(IsolatedAsyncioTestCase):
    @patch("app.celery.event_email_task.FastMail.send_message", new_callable=AsyncMock)
    async def test_send_email_success(self, send):
        await _send_email("test@example.com", "Test Subject", "<h1>Test Body</h1>")
        send.assert_awaited_once()
        message = send.call_args.args[0]
        self.assertEqual(message.subject, "Test Subject")
        self.assertEqual(message.recipients, ["test@example.com"])
        self.assertEqual(message.body, "<h1>Test Body</h1>")
        self.assertEqual(message.subtype, MessageType.html)
