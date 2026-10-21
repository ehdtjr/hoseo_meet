import asyncio
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig, MessageType
from app.celery.worker import app
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)

# FastMail 설정
conf = ConnectionConfig(
    MAIL_USERNAME=settings.SMTP_USER,
    MAIL_PASSWORD=settings.SMTP_PASSWORD,
    MAIL_FROM=settings.EMAIL_FROM_EMAIL,
    MAIL_PORT=settings.SMTP_PORT,
    MAIL_SERVER=settings.SMTP_HOST,
    MAIL_STARTTLS=settings.SMTP_TLS,
    MAIL_SSL_TLS=settings.SMTP_SSL,
    USE_CREDENTIALS=True,
    VALIDATE_CERTS=True,
)

@app.task(name="send_email_task")
def send_email_task(email: str, subject: str, body: str):
    """
    Celery 태스크: 이메일 발송
    """
    try:
        asyncio.run(_send_email(email, subject, body))
        logger.info(f"Email sent successfully to {email}")
    except Exception as e:
        logger.error(f"Failed to send email to {email}: {e}")
        raise

async def _send_email(email: str, subject: str, body: str):
    """
    실제 이메일 발송 (비동기 함수)
    """
    message = MessageSchema(
        subject=subject,
        recipients=[email],
        body=body,
        subtype=MessageType.html,
    )
    fm = FastMail(conf)
    try:
        await fm.send_message(message)
    except Exception as e:
        logger.error(f"Error sending email to {email}: {e}")
        raise
