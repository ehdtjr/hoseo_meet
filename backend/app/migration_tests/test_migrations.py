"""Alembic integration tests that run only against a disposable database.

These tests are intentionally outside ``app/tests``.  They require an explicit
``MIGRATION_TEST_DATABASE_URL`` whose database name is ``migration_test_db`` so
an ordinary developer or production database cannot be reset by accident.
"""

from __future__ import annotations

import asyncio
import os
import shutil
import subprocess
import sys
from io import StringIO
from pathlib import Path
from textwrap import dedent

import psycopg
import pytest
from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import text
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import create_async_engine


BASELINE_REVISION = "20261106_0001"
PROFILE_MEDIA_REVISION = "20261106_0002"
HEAD_REVISION = "20261106_0003"
DATABASE_NAME = "migration_test_db"
BACKEND_ROOT = Path(__file__).resolve().parents[2]
ALEMBIC_DIR = BACKEND_ROOT / "app" / "alembic"


def _required_test_url() -> str:
    raw_url = os.environ.get("MIGRATION_TEST_DATABASE_URL")
    if not raw_url:
        raise RuntimeError(
            "MIGRATION_TEST_DATABASE_URL is required; migration tests never use the app database"
        )
    url = make_url(raw_url)
    if url.database != DATABASE_NAME:
        raise RuntimeError(
            f"Migration tests may only reset the dedicated {DATABASE_NAME!r} database"
        )
    if not url.host or not url.username:
        raise RuntimeError(
            "MIGRATION_TEST_DATABASE_URL must identify a PostgreSQL server and user"
        )
    return url.render_as_string(hide_password=False)


TEST_URL = _required_test_url()
PARSED_URL = make_url(TEST_URL)

# app.core.config is imported by Alembic's env.py and the adoption CLI.  Set its
# component fields before importing any application modules so both paths point
# at the guarded disposable database.
os.environ.update(
    {
        "POSTGRES_SERVER": str(PARSED_URL.host),
        "POSTGRES_PORT": str(PARSED_URL.port or 5432),
        "POSTGRES_USER": str(PARSED_URL.username),
        "POSTGRES_PASSWORD": str(PARSED_URL.password or ""),
        "POSTGRES_DB": DATABASE_NAME,
    }
)


def _alembic_config(script_location: Path = ALEMBIC_DIR) -> Config:
    config = Config()
    config.set_main_option("script_location", str(script_location))
    _set_database_url(config)
    return config


def _set_database_url(config: Config) -> None:
    # ConfigParser treats percent signs in URL-encoded passwords as
    # interpolation tokens. Doubling them preserves the literal URL returned by
    # get_main_option while supporting arbitrary generated test passwords.
    config.set_main_option("sqlalchemy.url", TEST_URL.replace("%", "%%"))


async def _run_sql(*statements: str) -> list[object]:
    engine = create_async_engine(TEST_URL)
    try:
        async with engine.begin() as connection:
            database = await connection.scalar(text("SELECT current_database()"))
            if database != DATABASE_NAME:
                raise RuntimeError(
                    f"Refusing migration test operation on unexpected database {database!r}"
                )
            await connection.execute(text("SET LOCAL search_path TO public"))
            results: list[object] = []
            for statement in statements:
                result = await connection.execute(text(statement))
                results.append(
                    result.scalar_one_or_none() if result.returns_rows else None
                )
            return results
    finally:
        await engine.dispose()


def _sql(*statements: str) -> list[object]:
    return asyncio.run(_run_sql(*statements))


def _insert_generated_user(email: str, name: str) -> int:
    generated_id = _sql(
        'INSERT INTO public."user" '
        "(email, hashed_password, is_active, is_superuser, is_verified, name, gender) "
        f"VALUES ('{email}', 'synthetic-hash', true, false, true, '{name}', 'other') "
        "RETURNING id"
    )[0]
    assert isinstance(generated_id, int)
    return generated_id


def _assert_pending_outbox_marker() -> None:
    assert _sql(
        "SELECT outbox.payload FROM public.message_outbox AS outbox "
        "JOIN public.message AS message ON message.id = outbox.message_id "
        "WHERE message.client_message_id = 'migration-client-marker' "
        "AND outbox.completed_at IS NULL"
    ) == ["migration-outbox-marker"]


def _reset_database() -> None:
    _sql(
        "DROP SCHEMA public CASCADE",
        "CREATE SCHEMA public AUTHORIZATION CURRENT_USER",
    )


async def _create_legacy_schema(*, revision: str = BASELINE_REVISION) -> None:
    # Existing unversioned installations match the frozen baseline, not today's
    # ORM metadata.  Loading it from the tracked revision also prevents this
    # fixture from silently changing when a model is edited later.
    if revision not in (BASELINE_REVISION, PROFILE_MEDIA_REVISION, HEAD_REVISION):
        raise ValueError(f"Unsupported legacy fixture revision: {revision}")
    baseline = ScriptDirectory.from_config(_alembic_config()).get_revision(
        BASELINE_REVISION
    )
    assert baseline is not None
    baseline_metadata = baseline.module.schema()
    if revision in (PROFILE_MEDIA_REVISION, HEAD_REVISION):
        profile_media = ScriptDirectory.from_config(_alembic_config()).get_revision(
            PROFILE_MEDIA_REVISION
        )
        assert profile_media is not None
        profile_media.module.add_table(baseline_metadata)
    if revision == HEAD_REVISION:
        outbox = ScriptDirectory.from_config(_alembic_config()).get_revision(
            HEAD_REVISION
        )
        assert outbox is not None
        outbox.module.extend_schema(baseline_metadata)

    engine = create_async_engine(TEST_URL)
    try:
        async with engine.begin() as connection:
            database = await connection.scalar(text("SELECT current_database()"))
            if database != DATABASE_NAME:
                raise RuntimeError(f"Refusing legacy fixture creation on {database!r}")
            await connection.execute(text("SET LOCAL search_path TO public"))
            await connection.execute(text("CREATE EXTENSION IF NOT EXISTS postgis"))
            await connection.run_sync(baseline_metadata.create_all)
            await connection.execute(
                text(
                    'INSERT INTO "user" '
                    "(email, hashed_password, is_active, is_superuser, is_verified, name, gender) "
                    "VALUES (:email, :password, true, false, true, :name, :gender)"
                ),
                {
                    "email": "migration-marker@example.com",
                    "password": "synthetic-hash",
                    "name": "migration marker",
                    "gender": "other",
                },
            )
            if revision == HEAD_REVISION:
                user_id = await connection.scalar(
                    text(
                        'SELECT id FROM "user" '
                        "WHERE email = 'migration-marker@example.com'"
                    )
                )
                recipient_id = await connection.scalar(
                    text(
                        "INSERT INTO recipient (type, type_id) VALUES (1, :user_id) "
                        "RETURNING id"
                    ),
                    {"user_id": user_id},
                )
                message_id = await connection.scalar(
                    text(
                        "INSERT INTO message "
                        "(sender_id, type, recipient_id, content, client_message_id, "
                        "date_sent, has_attachment, has_image, has_link) "
                        "VALUES (:user_id, 'NORMAL', :recipient_id, :content, "
                        ":client_message_id, now(), false, false, false) RETURNING id"
                    ),
                    {
                        "user_id": user_id,
                        "recipient_id": recipient_id,
                        "content": "migration outbox source",
                        "client_message_id": "migration-client-marker",
                    },
                )
                await connection.execute(
                    text(
                        "INSERT INTO message_outbox "
                        "(message_id, user_id, stream_id, payload, channel, attempts) "
                        "VALUES (:message_id, :user_id, 0, :payload, 'route', 0)"
                    ),
                    {
                        "message_id": message_id,
                        "user_id": user_id,
                        "payload": "migration-outbox-marker",
                    },
                )
    finally:
        await engine.dispose()


async def _strict_application_schema_drift() -> list[str]:
    from app.alembic.schema_validation import validate_schema
    from app.core.db import Base
    import app.models  # noqa: F401
    import app.domains.restaurant.model  # noqa: F401

    engine = create_async_engine(TEST_URL)
    try:
        async with engine.begin() as connection:
            await connection.execute(text("SET LOCAL search_path TO public"))
            return await connection.run_sync(
                lambda sync_connection: validate_schema(
                    sync_connection, Base.metadata, schema="public"
                )
            )
    finally:
        await engine.dispose()


def _run_adoption() -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["MIGRATION_TEST_DATABASE_URL"] = TEST_URL
    return subprocess.run(
        [sys.executable, "-m", "app.scripts.adopt_legacy_db"],
        cwd=BACKEND_ROOT,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )


@pytest.fixture(autouse=True)
def disposable_database():
    _reset_database()
    yield
    _reset_database()


def test_empty_database_upgrades_to_current_schema_and_repeats_cleanly() -> None:
    config = _alembic_config()
    script = ScriptDirectory.from_config(config)
    assert script.get_current_head() == HEAD_REVISION

    command.upgrade(config, "head")
    assert _sql("SELECT version_num FROM public.alembic_version") == [HEAD_REVISION]

    # A second run must be a no-op and schema autogeneration must find no drift.
    command.upgrade(config, "head")
    assert _sql("SELECT version_num FROM public.alembic_version") == [HEAD_REVISION]
    command.check(config)
    assert asyncio.run(_strict_application_schema_drift()) == []


def test_unversioned_matching_database_is_adopted_without_losing_data() -> None:
    asyncio.run(_create_legacy_schema())

    result = _run_adoption()
    assert result.returncode == 0, result.stdout + result.stderr
    assert _sql("SELECT version_num FROM public.alembic_version") == [BASELINE_REVISION]
    assert _sql("SELECT to_regclass('public.profile_media')") == [None]
    assert _sql(
        "SELECT email FROM public.\"user\" WHERE email = 'migration-marker@example.com'"
    ) == ["migration-marker@example.com"]
    marker_id = _sql(
        "SELECT id FROM public.\"user\" WHERE email = 'migration-marker@example.com'"
    )[0]
    assert (
        _insert_generated_user("migration-generated@example.com", "migration generated")
        > marker_id
    )

    # Once stamped, the ordinary upgrade path remains idempotent.
    command.upgrade(_alembic_config(), "head")
    assert _sql("SELECT version_num FROM public.alembic_version") == [HEAD_REVISION]
    marker_id = _sql(
        "SELECT id FROM public.\"user\" WHERE email = 'migration-marker@example.com'"
    )[0]
    assert (
        _insert_generated_user(
            "migration-current-generated@example.com", "migration current generated"
        )
        > marker_id
    )
    assert _sql("SELECT to_regclass('public.profile_media')") == ["profile_media"]
    assert _sql("SELECT to_regclass('public.message_outbox')") == ["message_outbox"]
    assert _sql(
        "SELECT email FROM public.\"user\" WHERE email = 'migration-marker@example.com'"
    ) == ["migration-marker@example.com"]


def test_unversioned_profile_media_schema_upgrades_to_head() -> None:
    asyncio.run(_create_legacy_schema(revision=PROFILE_MEDIA_REVISION))

    result = _run_adoption()
    assert result.returncode == 0, result.stdout + result.stderr
    assert _sql("SELECT version_num FROM public.alembic_version") == [
        PROFILE_MEDIA_REVISION
    ]
    assert _sql("SELECT to_regclass('public.profile_media')") == ["profile_media"]
    assert _sql("SELECT to_regclass('public.message_outbox')") == [None]
    assert _sql(
        "SELECT EXISTS ("
        "SELECT 1 FROM information_schema.columns "
        "WHERE table_schema = 'public' AND table_name = 'message' "
        "AND column_name = 'client_message_id')"
    ) == [False]

    command.upgrade(_alembic_config(), "head")
    assert _sql("SELECT version_num FROM public.alembic_version") == [HEAD_REVISION]
    assert _sql("SELECT to_regclass('public.message_outbox')") == ["message_outbox"]
    assert _sql(
        "SELECT EXISTS ("
        "SELECT 1 FROM information_schema.columns "
        "WHERE table_schema = 'public' AND table_name = 'message' "
        "AND column_name = 'client_message_id')"
    ) == [True]
    assert _sql(
        "SELECT email FROM public.\"user\" WHERE email = 'migration-marker@example.com'"
    ) == ["migration-marker@example.com"]


def test_unversioned_current_schema_is_adopted_at_head() -> None:
    asyncio.run(_create_legacy_schema(revision=HEAD_REVISION))

    result = _run_adoption()
    assert result.returncode == 0, result.stdout + result.stderr
    assert _sql("SELECT version_num FROM public.alembic_version") == [HEAD_REVISION]
    assert _sql("SELECT to_regclass('public.profile_media')") == ["profile_media"]
    assert _sql(
        "SELECT email FROM public.\"user\" WHERE email = 'migration-marker@example.com'"
    ) == ["migration-marker@example.com"]
    _assert_pending_outbox_marker()

    command.upgrade(_alembic_config(), "head")
    assert _sql("SELECT version_num FROM public.alembic_version") == [HEAD_REVISION]
    marker_id = _sql(
        "SELECT id FROM public.\"user\" WHERE email = 'migration-marker@example.com'"
    )[0]
    assert (
        _insert_generated_user(
            "migration-head-generated@example.com", "migration head generated"
        )
        > marker_id
    )
    _assert_pending_outbox_marker()


def test_current_adoption_rejects_partial_outbox_schema() -> None:
    asyncio.run(_create_legacy_schema(revision=HEAD_REVISION))
    _sql(
        "DROP INDEX public.message_outbox_channel_pending",
        "CREATE INDEX message_outbox_channel_pending "
        "ON public.message_outbox (channel, available_at, id) "
        "WHERE completed_at IS NOT NULL",
    )

    result = _run_adoption()
    assert result.returncode != 0
    assert _sql("SELECT to_regclass('public.alembic_version')") == [None]
    _assert_pending_outbox_marker()


def test_legacy_adoption_accepts_renamed_owned_serial_sequence() -> None:
    asyncio.run(_create_legacy_schema())
    _sql("ALTER SEQUENCE public.user_id_seq RENAME TO renamed_user_id_seq")

    result = _run_adoption()
    assert result.returncode == 0, result.stdout + result.stderr
    assert _sql("SELECT version_num FROM public.alembic_version") == [BASELINE_REVISION]

    command.upgrade(_alembic_config(), "head")
    marker_id = _sql(
        "SELECT id FROM public.\"user\" WHERE email = 'migration-marker@example.com'"
    )[0]
    assert (
        _insert_generated_user(
            "migration-renamed-sequence@example.com", "migration renamed sequence"
        )
        == marker_id + 1
    )


@pytest.mark.parametrize(
    "drift_statements",
    [
        ('ALTER TABLE public."user" ADD COLUMN legacy_only text',),
        ("DROP TABLE public.terms CASCADE",),
        ("CREATE TABLE public.legacy_only_table (id integer PRIMARY KEY)",),
        ("ALTER TABLE public.meet_post DROP CONSTRAINT check_max_people",),
        ("ALTER TYPE public.messagetype ADD VALUE 'MIGRATION_DRIFT'",),
        (
            "DROP INDEX public.subscription_recipient_id_user_id_idx",
            "CREATE INDEX subscription_recipient_id_user_id_idx "
            "ON public.subscriptions (recipient_id, user_id) "
            "WHERE active = false AND is_user_active = true",
        ),
        (
            "ALTER TABLE public.message DROP COLUMN search_tsvector",
            "ALTER TABLE public.message ADD COLUMN search_tsvector tsvector "
            "GENERATED ALWAYS AS (to_tsvector('english'::regconfig, content)) STORED",
            "CREATE INDEX ix_message_search_tsvector "
            "ON public.message (search_tsvector)",
            "CREATE INDEX message_search_tsvector_idx "
            "ON public.message USING gin (search_tsvector)",
        ),
        (
            "ALTER TABLE public.restaurant_review_image "
            "DROP CONSTRAINT restaurant_review_image_pkey",
            "ALTER TABLE public.restaurant_review_image "
            "ADD PRIMARY KEY (review_id, post_id)",
        ),
        ('ALTER TABLE public."user" ALTER COLUMN id DROP DEFAULT',),
        ('ALTER TABLE public."user" ALTER COLUMN id SET DEFAULT 1',),
        (
            'ALTER TABLE public."user" ALTER COLUMN id '
            "SET DEFAULT nextval('public.recipient_id_seq'::regclass)",
        ),
        ("ALTER SEQUENCE public.user_id_seq OWNED BY NONE",),
        ("ALTER SEQUENCE public.user_id_seq INCREMENT BY 2",),
        ("ALTER SEQUENCE public.user_id_seq CYCLE",),
    ],
    ids=[
        "extra-column",
        "missing-table",
        "extra-table",
        "changed-check-constraint",
        "changed-enum",
        "changed-partial-index-predicate",
        "changed-generated-expression",
        "changed-primary-key",
        "missing-serial-default",
        "constant-serial-default",
        "foreign-sequence-default",
        "detached-sequence-ownership",
        "changed-sequence-increment",
        "changed-sequence-cycle",
    ],
)
def test_legacy_adoption_rejects_schema_drift_without_stamping(
    drift_statements: tuple[str, ...],
) -> None:
    asyncio.run(_create_legacy_schema())
    _sql(*drift_statements)

    result = _run_adoption()
    combined_output = (result.stdout + result.stderr).lower()
    assert result.returncode != 0
    assert "drift" in combined_output or "schema" in combined_output
    assert _sql("SELECT to_regclass('public.alembic_version')") == [None]
    assert _sql(
        "SELECT email FROM public.\"user\" WHERE email = 'migration-marker@example.com'"
    ) == ["migration-marker@example.com"]


def test_ci_schema_check_detects_an_untracked_column() -> None:
    config = _alembic_config()
    command.upgrade(config, "head")
    _sql('ALTER TABLE public."user" ADD COLUMN ci_drift_probe text')

    with pytest.raises(Exception, match="(?i)(upgrade operations|drift|column)"):
        command.check(config)


def test_baseline_downgrade_is_explicitly_blocked() -> None:
    config = _alembic_config()
    command.upgrade(config, "head")

    with pytest.raises(Exception, match="(?i)(baseline|backup|downgrade)"):
        command.downgrade(config, "base")
    # 0003/0002 downgrades and baseline's refusal share the real env transaction.
    assert _sql("SELECT version_num FROM public.alembic_version") == [HEAD_REVISION]
    assert _sql("SELECT to_regclass('public.profile_media')") == ["profile_media"]
    assert _sql("SELECT to_regclass('public.message_outbox')") == ["message_outbox"]
    assert _sql(
        "SELECT EXISTS ("
        "SELECT 1 FROM information_schema.columns "
        "WHERE table_schema = 'public' AND table_name = 'message' "
        "AND column_name = 'client_message_id')"
    ) == [True]


def test_failed_revision_rolls_back_and_can_be_retried(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Exercise failure and retry through the application's actual env.py."""

    asyncio.run(_create_legacy_schema())
    command.stamp(_alembic_config(), BASELINE_REVISION)
    assert _sql("SELECT version_num FROM public.alembic_version") == [BASELINE_REVISION]

    script_dir = tmp_path / "alembic"
    versions_dir = script_dir / "versions"
    versions_dir.mkdir(parents=True)
    shutil.copy2(ALEMBIC_DIR / "env.py", script_dir / "env.py")
    for revision_file in (
        "20261106_0001_baseline.py",
        "20261106_0002_profile_media.py",
        "20261106_0003_message_outbox.py",
    ):
        shutil.copy2(
            ALEMBIC_DIR / "versions" / revision_file, versions_dir / revision_file
        )
    (versions_dir / "20261106_0004_failure_probe.py").write_text(
        dedent(
            """
            import os
            from alembic import op
            import sqlalchemy as sa

            revision = "probe_004"
            down_revision = "20261106_0003"
            branch_labels = None
            depends_on = None

            def upgrade():
                op.create_table("migration_failure_probe", sa.Column("id", sa.Integer, primary_key=True))
                if os.environ.get("MIGRATION_FAILURE_PROBE") == "fail":
                    op.execute("SELECT definitely_missing_failure_function()")

            def downgrade():
                op.drop_table("migration_failure_probe")
            """
        )
    )

    config = Config()
    config.set_main_option("script_location", str(script_dir))
    _set_database_url(config)

    monkeypatch.setenv("MIGRATION_FAILURE_PROBE", "fail")
    with pytest.raises(Exception):
        command.upgrade(config, "head")
    assert _sql("SELECT version_num FROM public.alembic_version") == [BASELINE_REVISION]
    assert _sql("SELECT to_regclass('public.profile_media')") == [None]
    assert _sql("SELECT to_regclass('public.message_outbox')") == [None]
    assert _sql(
        "SELECT EXISTS ("
        "SELECT 1 FROM information_schema.columns "
        "WHERE table_schema = 'public' AND table_name = 'message' "
        "AND column_name = 'client_message_id')"
    ) == [False]
    assert _sql("SELECT to_regclass('public.migration_failure_probe')") == [None]
    assert _sql(
        "SELECT email FROM public.\"user\" WHERE email = 'migration-marker@example.com'"
    ) == ["migration-marker@example.com"]

    monkeypatch.delenv("MIGRATION_FAILURE_PROBE")
    command.upgrade(config, "head")
    assert _sql("SELECT version_num FROM public.alembic_version") == ["probe_004"]
    assert _sql("SELECT to_regclass('public.profile_media')") == ["profile_media"]
    assert _sql("SELECT to_regclass('public.message_outbox')") == ["message_outbox"]
    assert _sql(
        "SELECT EXISTS ("
        "SELECT 1 FROM information_schema.columns "
        "WHERE table_schema = 'public' AND table_name = 'message' "
        "AND column_name = 'client_message_id')"
    ) == [True]
    assert _sql("SELECT to_regclass('public.migration_failure_probe')") == [
        "migration_failure_probe"
    ]
    assert _sql(
        "SELECT email FROM public.\"user\" WHERE email = 'migration-marker@example.com'"
    ) == ["migration-marker@example.com"]


def test_offline_sql_targets_public_with_shadow_first_in_search_path() -> None:
    output = StringIO()
    config = _alembic_config()
    config.output_buffer = output
    command.upgrade(config, "head", sql=True)
    offline_sql = output.getvalue()
    assert offline_sql
    assert "SET LOCAL search_path TO public" in offline_sql

    sync_url = (
        make_url(TEST_URL)
        .set(drivername="postgresql")
        .render_as_string(hide_password=False)
    )
    with psycopg.connect(sync_url, autocommit=True) as connection:
        database = connection.execute("SELECT current_database()").fetchone()[0]
        if database != DATABASE_NAME:
            raise RuntimeError(
                f"Refusing offline migration test on unexpected database {database!r}"
            )
        connection.execute("DROP SCHEMA IF EXISTS migration_shadow CASCADE")
        connection.execute("CREATE SCHEMA migration_shadow AUTHORIZATION CURRENT_USER")
        try:
            connection.execute("SET search_path TO migration_shadow, public")
            assert connection.execute("SHOW search_path").fetchone()[0] == (
                "migration_shadow, public"
            )
            with psycopg.ClientCursor(connection) as cursor:
                cursor.execute(offline_sql)

            from app.core.db import Base
            import app.models  # noqa: F401
            import app.domains.restaurant.model  # noqa: F401

            expected_tables = {table.name for table in Base.metadata.tables.values()}
            expected_tables.add("alembic_version")
            public_tables = {
                row[0]
                for row in connection.execute(
                    "SELECT tablename FROM pg_catalog.pg_tables "
                    "WHERE schemaname = 'public'"
                ).fetchall()
            }
            assert expected_tables <= public_tables
            assert (
                connection.execute(
                    "SELECT version_num FROM public.alembic_version"
                ).fetchone()[0]
                == HEAD_REVISION
            )
            assert connection.execute(
                "SELECT EXISTS ("
                "SELECT 1 FROM pg_catalog.pg_type AS type "
                "JOIN pg_catalog.pg_namespace AS namespace "
                "ON namespace.oid = type.typnamespace "
                "WHERE namespace.nspname = 'public' "
                "AND type.typname = 'messagetype'"
                ")"
            ).fetchone()[0]
            assert (
                connection.execute(
                    "SELECT count(*) FROM pg_catalog.pg_class AS class "
                    "JOIN pg_catalog.pg_namespace AS namespace "
                    "ON namespace.oid = class.relnamespace "
                    "WHERE namespace.nspname = 'migration_shadow'"
                ).fetchone()[0]
                == 0
            )
            assert (
                connection.execute(
                    "SELECT count(*) FROM pg_catalog.pg_type AS type "
                    "JOIN pg_catalog.pg_namespace AS namespace "
                    "ON namespace.oid = type.typnamespace "
                    "WHERE namespace.nspname = 'migration_shadow'"
                ).fetchone()[0]
                == 0
            )
        finally:
            connection.rollback()
            connection.execute("SET search_path TO public")
            connection.execute("DROP SCHEMA migration_shadow CASCADE")

    online_config = _alembic_config()
    command.upgrade(online_config, "head")
    command.check(online_config)
    assert asyncio.run(_strict_application_schema_drift()) == []
