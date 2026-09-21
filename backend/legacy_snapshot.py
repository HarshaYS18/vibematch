"""Frozen schema bridge, used exclusively by Alembic revisions."""
import json
from pathlib import Path

from sqlalchemy import inspect, text
from alembic import op

MARKER = "_alembic_legacy_bootstrap"


def create_table(name, *columns, **kwargs):
    if not inspect(op.get_bind()).has_table(name):
        return op.create_table(name, *columns, **kwargs)


def add_column(table, column, **kwargs):
    if column.name not in {item["name"] for item in inspect(op.get_bind()).get_columns(table)}:
        op.add_column(table, column, **kwargs)


def create_index(name, table, columns, **kwargs):
    if str(name) not in {item["name"] for item in inspect(op.get_bind()).get_indexes(table)}:
        op.create_index(name, table, columns, **kwargs)


def snapshot():
    return json.loads((Path(__file__).with_name("alembic") / "schema_20260921.json").read_text(encoding="utf-8"))


def is_fresh_bootstrap(bind):
    return inspect(bind).has_table(MARKER)


def create_missing_tables(bind):
    if bind.dialect.name != "postgresql":
        raise RuntimeError("The production migration history requires PostgreSQL.")
    schema = snapshot()
    existing_enums = {entry["name"] for entry in inspect(bind).get_enums()}
    for name, values in schema["enums"].items():
        if name not in existing_enums:
            quoted = ", ".join("'" + value.replace("'", "''") + "'" for value in values)
            bind.execute(text(f'CREATE TYPE "{name}" AS ENUM ({quoted})'))
    existing = set(inspect(bind).get_table_names())
    for table in schema["tables"]:
        if table["name"] not in existing:
            bind.execute(text(table["create"]))
            for ddl in table["indexes"].values():
                bind.execute(text(ddl))


def assert_snapshot_columns(bind):
    inspector = inspect(bind)
    missing = []
    for table in snapshot()["tables"]:
        actual = {c["name"] for c in inspector.get_columns(table["name"])}
        missing.extend(f'{table["name"]}.{name}' for name in table["columns"] if name not in actual)
    if missing:
        raise RuntimeError("Legacy database requires an explicit data migration for missing columns: " + ", ".join(missing))
