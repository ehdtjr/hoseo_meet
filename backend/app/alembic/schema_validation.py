"""Strict PostgreSQL checks used before adopting an unversioned database.

Alembic's normal ``compare_metadata`` remains the primary comparison. This
module covers details it does not reliably compare: primary keys, SERIAL
defaults and sequence ownership, CHECK
expressions, generated columns, enum labels, and partial-index predicates and
methods.

PostgreSQL canonicalizes expressions by planning ``SELECT (expression)`` with
``EXPLAIN``. The query does not change data. PostgreSQL may evaluate constant
immutable functions while planning, so this is only suitable for the reviewed
expressions in a known migration snapshot. Triggers, policies, grants, views,
functions, and extension-owned objects require separate operational checks.
"""

from __future__ import annotations

import json
from typing import Any, Iterable

import sqlalchemy as sa
from sqlalchemy import inspect
from sqlalchemy.engine import Connection
from sqlalchemy.engine.reflection import Inspector
from sqlalchemy.sql.schema import CheckConstraint, MetaData, Table


class SchemaValidationError(RuntimeError):
    """Raised when PostgreSQL cannot safely canonicalize an expression."""


def validate_schema(
    connection: Connection,
    expected_metadata: MetaData,
    *,
    schema: str = "public",
) -> list[str]:
    """Return differences that supplement Alembic ``compare_metadata``."""

    inspector = inspect(connection)
    actual_tables = set(inspector.get_table_names(schema=schema))
    expected_tables = {
        table.name: table
        for table in expected_metadata.tables.values()
        if (table.schema or inspector.default_schema_name) == schema
    }
    differences: list[str] = []
    for table_name in sorted(set(expected_tables) & actual_tables):
        table = expected_tables[table_name]
        differences.extend(_primary_key_differences(inspector, table, schema))
        differences.extend(_serial_default_differences(connection, table, schema))
        differences.extend(_check_differences(connection, inspector, table, schema))
        differences.extend(
            _generated_column_differences(connection, inspector, table, schema)
        )
        differences.extend(_index_differences(connection, inspector, table, schema))
    differences.extend(_enum_differences(inspector, expected_tables.values(), schema))
    return differences


def _serial_default_differences(
    connection: Connection, table: Table, schema: str
) -> list[str]:
    # PostgreSQL renders these integer primary keys as SERIAL. Alembic skips
    # their defaults entirely, including a missing or replaced nextval().
    column = table.autoincrement_column
    if (
        column is None
        or column.identity is not None
        or column.server_default is not None
    ):
        return []
    actual = (
        connection.execute(
            sa.text(
                """
            SELECT pg_get_expr(d.adbin, d.adrelid) AS actual_default,
                   CASE WHEN s.oid IS NOT NULL THEN
                       format('nextval(%L::regclass)', s.oid::regclass::text)
                   END AS serial_default,
                   s.relnamespace = n.oid AS same_schema,
                   format_type(q.seqtypid, NULL) AS sequence_type,
                   q.seqstart, q.seqincrement, q.seqmin, q.seqmax,
                   q.seqcache, q.seqcycle
            FROM pg_catalog.pg_class AS t
            JOIN pg_catalog.pg_namespace AS n ON n.oid = t.relnamespace
            JOIN pg_catalog.pg_attribute AS a ON a.attrelid = t.oid
            LEFT JOIN pg_catalog.pg_attrdef AS d
                ON d.adrelid = t.oid AND d.adnum = a.attnum
            LEFT JOIN pg_catalog.pg_class AS s
                ON s.oid = pg_get_serial_sequence(
                    format('%I.%I', n.nspname, t.relname), a.attname
                )::regclass AND s.relkind = 'S'
            LEFT JOIN pg_catalog.pg_sequence AS q ON q.seqrelid = s.oid
            WHERE n.nspname = :schema AND t.relname = :table
                AND a.attname = :column AND NOT a.attisdropped
            """
            ),
            {"schema": schema, "table": table.name, "column": column.name},
        )
        .mappings()
        .one_or_none()
    )
    # Missing tables/columns are reported by the ordinary Alembic comparison.
    if actual is None:
        return []
    if isinstance(column.type, sa.BigInteger):
        sequence_type, bits = "bigint", 64
    elif isinstance(column.type, sa.SmallInteger):
        sequence_type, bits = "smallint", 16
    else:
        sequence_type, bits = "integer", 32
    expected_sequence = {
        "same_schema": True,
        "sequence_type": sequence_type,
        "seqstart": 1,
        "seqincrement": 1,
        "seqmin": 1,
        "seqmax": (1 << (bits - 1)) - 1,
        "seqcache": 1,
        "seqcycle": False,
    }
    # Compare catalog expressions without evaluating nextval or advancing any
    # sequence. Resolve the owned sequence rather than guessing its name, so
    # a harmless sequence rename remains valid but another table's sequence
    # or a constant/expression default cannot be stamped as this baseline.
    if (
        actual["serial_default"] is None
        or actual["actual_default"] != actual["serial_default"]
        or any(actual[key] != value for key, value in expected_sequence.items())
    ):
        return [
            f"{table.name}.{column.name}: SERIAL default, sequence ownership or configuration differs"
        ]
    return []


def _primary_key_differences(
    inspector: Inspector, table: Table, schema: str
) -> list[str]:
    expected = tuple(column.name for column in table.primary_key.columns)
    actual_info = inspector.get_pk_constraint(table.name, schema=schema)
    actual = tuple(actual_info.get("constrained_columns") or ())
    differences = []
    if expected != actual:
        differences.append(
            f"{table.name}: primary key differs; expected {expected!r}, found {actual!r}"
        )
    if table.primary_key.name and table.primary_key.name != actual_info.get("name"):
        differences.append(
            f"{table.name}: primary key name differs; expected "
            f"{table.primary_key.name!r}, found {actual_info.get('name')!r}"
        )
    return differences


def _check_differences(
    connection: Connection, inspector: Inspector, table: Table, schema: str
) -> list[str]:
    expected = [
        constraint
        for constraint in table.constraints
        if isinstance(constraint, CheckConstraint)
    ]
    actual = list(inspector.get_check_constraints(table.name, schema=schema))
    differences: list[str] = []
    for constraint in sorted(expected, key=lambda item: item.name or ""):
        expected_expression = _canonical_expression(
            connection, table.name, _compile(connection, constraint.sqltext), schema
        )
        match = None
        for candidate in actual:
            if constraint.name and candidate.get("name") != constraint.name:
                continue
            if (
                _canonical_expression(
                    connection,
                    table.name,
                    str(candidate.get("sqltext", "")),
                    schema,
                )
                == expected_expression
            ):
                match = candidate
                break
        if match is None:
            differences.append(
                f"{table.name}: missing or changed CHECK "
                f"{constraint.name or expected_expression!r}"
            )
        else:
            actual.remove(match)
    differences.extend(
        f"{table.name}: unexpected CHECK {constraint.get('name')!r}"
        for constraint in actual
    )
    return differences


def _generated_column_differences(
    connection: Connection, inspector: Inspector, table: Table, schema: str
) -> list[str]:
    actual_columns = {
        column["name"]: column
        for column in inspector.get_columns(table.name, schema=schema)
    }
    differences: list[str] = []
    for column in table.columns:
        actual = actual_columns.get(column.name)
        if actual is None:
            continue
        expected_computed = column.computed
        actual_computed = actual.get("computed")
        if (expected_computed is None) != (actual_computed is None):
            differences.append(f"{table.name}.{column.name}: generated status differs")
            continue
        if expected_computed is None:
            continue
        expected_expression = _canonical_expression(
            connection,
            table.name,
            _compile(connection, expected_computed.sqltext),
            schema,
        )
        actual_expression = _canonical_expression(
            connection,
            table.name,
            str(actual_computed.get("sqltext", "")),
            schema,
        )
        if expected_expression != actual_expression:
            differences.append(
                f"{table.name}.{column.name}: generated expression differs"
            )
        expected_persisted = expected_computed.persisted
        actual_persisted = actual_computed.get("persisted")
        if (expected_persisted is not False) != (actual_persisted is not False):
            differences.append(
                f"{table.name}.{column.name}: generated persistence differs"
            )
    return differences


def _index_differences(
    connection: Connection, inspector: Inspector, table: Table, schema: str
) -> list[str]:
    actual_by_name = {
        index["name"]: index
        for index in inspector.get_indexes(table.name, schema=schema)
        if not index.get("duplicates_constraint")
    }
    differences: list[str] = []
    for index in table.indexes:
        actual = actual_by_name.get(index.name)
        if actual is None:
            continue
        expected_options = index.dialect_options["postgresql"]
        actual_options = actual.get("dialect_options") or {}
        expected_method = expected_options.get("using") or "btree"
        actual_method = actual_options.get("postgresql_using") or "btree"
        if expected_method != actual_method:
            differences.append(
                f"{table.name}.{index.name}: index method differs; expected "
                f"{expected_method!r}, found {actual_method!r}"
            )
        expected_where = expected_options.get("where")
        actual_where = actual_options.get("postgresql_where")
        if (expected_where is None) != (actual_where is None):
            differences.append(
                f"{table.name}.{index.name}: partial predicate status differs"
            )
        elif expected_where is not None:
            expected_expression = _canonical_expression(
                connection, table.name, _compile(connection, expected_where), schema
            )
            actual_expression = _canonical_expression(
                connection, table.name, str(actual_where), schema
            )
            if expected_expression != actual_expression:
                differences.append(
                    f"{table.name}.{index.name}: partial predicate differs"
                )
    return differences


def _enum_differences(
    inspector: Inspector, tables: Iterable[Table], schema: str
) -> list[str]:
    expected: dict[str, tuple[str, ...]] = {}
    for table in tables:
        for column in table.columns:
            type_ = column.type
            if isinstance(type_, sa.Enum) and type_.native_enum and type_.name:
                if (type_.schema or inspector.default_schema_name) == schema:
                    expected[type_.name] = tuple(type_.enums)
    actual = {
        enum["name"]: tuple(enum.get("labels") or ())
        for enum in inspector.get_enums(schema=schema)
    }
    return [
        f"enum {name!r} labels differ; expected {expected.get(name)!r}, "
        f"found {actual.get(name)!r}"
        for name in sorted(set(expected) | set(actual))
        if expected.get(name) != actual.get(name)
    ]


def _canonical_expression(
    connection: Connection, table_name: str, expression: str, schema: str
) -> str:
    preparer = connection.dialect.identifier_preparer
    table = f"{preparer.quote_schema(schema)}.{preparer.quote(table_name)}"
    statement = "EXPLAIN (VERBOSE, FORMAT JSON) " f"SELECT ({expression}) FROM {table}"
    payload = connection.exec_driver_sql(statement).scalar_one()
    if isinstance(payload, str):
        payload = json.loads(payload)
    output = payload[0].get("Plan", {}).get("Output")
    if not output or not isinstance(output[0], str):
        raise SchemaValidationError(
            f"PostgreSQL did not canonicalize an expression for {table_name}"
        )
    return output[0]


def _compile(connection: Connection, expression: Any) -> str:
    return str(
        expression.compile(
            dialect=connection.dialect,
            compile_kwargs={"literal_binds": True},
        )
    )
