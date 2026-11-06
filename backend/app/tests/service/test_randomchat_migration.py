from datetime import datetime, timedelta, timezone
from unittest.mock import patch

from sqlalchemy import inspect, select

from app.models import RandomChatQueue, User
from app.scripts import migrate_randomchat
from app.tests.conftest import BaseTest, test_engine


class TestRandomChatMigration(BaseTest):
    async def test_existing_database_upgrade_and_rerun_preserve_data(self):
        user = User(email="migration@example.com", name="Migration user",
                    gender="male", hashed_password="synthetic",
                    is_active=True, is_verified=True, is_superuser=False)
        self.db.add(user)
        await self.db.flush()
        user_id = user.id
        await self.db.commit()

        # Model the old schema: all existing tables/data, no queue table yet.
        async with test_engine.begin() as connection:
            await connection.run_sync(RandomChatQueue.__table__.drop)
        with patch.object(migrate_randomchat, "engine", test_engine):
            await migrate_randomchat.main()

        now = datetime.now(timezone.utc)
        async with test_engine.begin() as connection:
            self.assertEqual(await connection.scalar(
                select(User.email).where(User.id == user_id)
            ), "migration@example.com")
            await connection.execute(RandomChatQueue.__table__.insert().values(
                user_id=user_id, queued_at=now,
                expires_at=now + timedelta(seconds=90),
            ))
            indexes = await connection.run_sync(
                lambda conn: inspect(conn).get_indexes("random_chat_queue")
            )
            foreign_keys = await connection.run_sync(
                lambda conn: inspect(conn).get_foreign_keys("random_chat_queue")
            )
            self.assertEqual({index["name"] for index in indexes}, {
                "ix_random_chat_queue_fifo", "ix_random_chat_queue_expiry",
            })
            self.assertEqual({fk["referred_table"] for fk in foreign_keys}, {
                "user", "streams",
            })

        with patch.object(migrate_randomchat, "engine", test_engine):
            await migrate_randomchat.main()
        async with test_engine.connect() as connection:
            self.assertEqual(await connection.scalar(
                select(RandomChatQueue.queued_at).where(
                    RandomChatQueue.user_id == user_id
                )
            ), now)
