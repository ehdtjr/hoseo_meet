from unittest import TestCase
from unittest.mock import patch, AsyncMock

from fastapi_mail import MessageType

from app.core.config import settings
from app.utils.email import send_email


class TestSendEmail(TestCase):
    @patch("app.utils.email.FastMail.send_message", new_callable=AsyncMock)
    @patch("app.utils.email.FastMail", autospec=True)
    @patch("app.core.config.settings", settings)
    async def test_send_email_success(self, mock_fastmail, mock_send_message):
        # Given
        test_email = "test@example.com"
        test_subject = "Test Subject"
        test_body = "<h1>Test Body</h1>"

        # When
        await send_email(test_email, test_subject, test_body)

        # Then
        mock_send_message.assert_awaited_once()
        message_instance = mock_send_message.call_args[0][0]

        self.assertEqual(message_instance.subject, test_subject)
        self.assertEqual(message_instance.recipients, [test_email])
        self.assertEqual(message_instance.body, test_body)
        self.assertEqual(message_instance.subtype, MessageType.html)
