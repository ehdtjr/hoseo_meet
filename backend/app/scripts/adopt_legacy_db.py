"""Validate a known unversioned schema before recording its exact revision.

Run once, with writers stopped and a verified backup. This never repairs drift
or guesses the revision of an unknown schema; follow it with `alembic upgrade head`.
"""

import asyncio
from pathlib import Path

from alembic import command
from alembic.autogenerate import compare_metadata
from alembic.config import Config
from alembic.migration import MigrationContext
from alembic.script import ScriptDirectory
from sqlalchemy import inspect, text
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.pool import NullPool

from app.core.config import settings

BASELINE = "20261106_0001"
PROFILE_MEDIA = "20261106_0002"


def adopt(connection, config):
    # Serializes concurrent adoption attempts. Stop application writers before
    # invoking this command; this lock cannot coordinate old application code.
    connection.execute(text("SELECT pg_advisory_xact_lock(260611060001)"))
    connection.execute(text("SET LOCAL search_path TO public"))
    inspector = inspect(connection)
    if inspector.default_schema_name != "public":
        raise RuntimeError("Legacy adoption requires the public schema")
    if "alembic_version" in inspector.get_table_names():
        raise RuntimeError(
            "Database already has Alembic history; use alembic upgrade head"
        )
    scripts = ScriptDirectory.from_config(config)
    metadata = scripts.get_revision(BASELINE).module.schema()
    revision = BASELINE
    if "profile_media" in inspector.get_table_names():
        scripts.get_revision(PROFILE_MEDIA).module.add_table(metadata)
        revision = PROFILE_MEDIA
    migration_context = MigrationContext.configure(
        connection,
        opts={
            "include_name": lambda name, type_, parent: type_ != "table"
            or name != "spatial_ref_sys",
            "compare_type": True,
            "compare_server_default": True,
        },
    )
    differences = compare_metadata(migration_context, metadata)
    from app.alembic.schema_validation import validate_schema

    differences.extend(validate_schema(connection, metadata))
    if differences:
        # Do not print reflected defaults/data, which may contain private values.
        raise RuntimeError(
            f"Legacy schema differs from revision {revision} ({len(differences)} differences); "
            "restore a copy and prepare a reviewed reconciliation migration before adoption"
        )
    config.attributes["connection"] = connection
    command.stamp(config, revision)
    print(
        f"Validated legacy schema; recorded revision {revision}. Run alembic upgrade head next."
    )


async def main():
    config = Config(str(Path(__file__).resolve().parents[2] / "alembic.ini"))
    engine = create_async_engine(
        str(settings.SQLALCHEMY_DATABASE_URI), poolclass=NullPool
    )
    try:
        async with engine.begin() as connection:
            await connection.run_sync(lambda conn: adopt(conn, config))
    finally:
        await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
