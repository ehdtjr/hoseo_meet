"""Alembic entry point; schema changes belong in versioned revisions only."""

import asyncio
from logging.config import fileConfig

from alembic import context
from sqlalchemy import pool, text
from sqlalchemy.ext.asyncio import async_engine_from_config

from app.core.config import settings
from app.core.db import Base
import app.models  # noqa: F401
import app.domains.restaurant.model  # noqa: F401

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)
target_metadata = Base.metadata


def get_url():
    return config.get_main_option("sqlalchemy.url") or str(
        settings.SQLALCHEMY_DATABASE_URI
    )


def include_name(name, type_, parent_names):
    # Ignore only PostGIS-owned tables, never unknown application tables: a stale
    # table must make `alembic check` fail just like a missing column does.
    return type_ != "table" or name != "spatial_ref_sys"


def options():
    return dict(
        target_metadata=target_metadata,
        include_name=include_name,
        compare_type=True,
        compare_server_default=True,
    )


def run_migrations_offline():
    context.configure(
        url=get_url(),
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        **options(),
    )
    with context.begin_transaction():
        # Emit this before Alembic creates its version table, just as online.
        context.execute("SET LOCAL search_path TO public")
        context.run_migrations()


def do_run_migrations(connection):
    context.configure(connection=connection, **options())
    with context.begin_transaction():
        # PostGIS images add tiger/topology to search_path. The application owns
        # public only; otherwise reflection mistakes extension tables for drift.
        connection.execute(text("SET LOCAL search_path TO public"))
        context.run_migrations()


async def run_async_migrations():
    connectable = async_engine_from_config(
        {"sqlalchemy.url": get_url()},
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    try:
        async with connectable.connect() as connection:
            await connection.run_sync(do_run_migrations)
    finally:
        await connectable.dispose()


def run_migrations_online():
    connection = config.attributes.get("connection")
    if connection is not None:
        do_run_migrations(connection)
    else:
        asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
