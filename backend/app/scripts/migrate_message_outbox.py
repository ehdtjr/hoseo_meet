"""Idempotent additive migration for existing databases (no Alembic baseline).

Run before starting the new API: python -m app.scripts.migrate_message_outbox
New databases are initialized by local_init with the same model metadata.
"""
import asyncio

from sqlalchemy import text

from app.core.db import engine
from app.models.message_outbox import MessageOutbox


async def migrate(connection):
    await connection.execute(text("SELECT pg_advisory_xact_lock(220022)"))
    await connection.execute(text(
        "ALTER TABLE message ADD COLUMN IF NOT EXISTS client_message_id VARCHAR(128)"))
    await connection.execute(text(
        "CREATE UNIQUE INDEX IF NOT EXISTS message_sender_client_id "
        "ON message (sender_id, client_message_id)"))
    await connection.run_sync(lambda conn: MessageOutbox.__table__.create(conn, checkfirst=True))
    await connection.execute(text(
        "ALTER TABLE message_outbox ADD COLUMN IF NOT EXISTS channel "
        "VARCHAR(16) NOT NULL DEFAULT 'route'"))
    await connection.execute(text(
        "CREATE INDEX IF NOT EXISTS message_outbox_channel_pending "
        "ON message_outbox (channel, available_at, id) WHERE completed_at IS NULL"))


async def main():
    try:
        async with engine.begin() as connection:
            await migrate(connection)
    finally:
        await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
