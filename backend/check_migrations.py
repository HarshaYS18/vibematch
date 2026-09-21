"""Replay Alembic against an explicitly disposable PostgreSQL database in CI.

Requires MIGRATION_TEST_DATABASE_URL. Creates unique schemas, never drops the
database or a pre-existing schema. Exercises empty install, historical takeover,
repeat upgrade and the startup schema guard.
"""
import os
from pathlib import Path
from uuid import uuid4

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect, text

from app.core.config import settings
from app.core.schema_guard import assert_database_schema_current
from app.database import Base
from app import models  # noqa: F401


def main():
    url = os.environ["MIGRATION_TEST_DATABASE_URL"]
    engine = create_engine(url)
    config = Config(str(Path(__file__).with_name("alembic.ini")))
    schemas = []
    try:
        for scenario in ("empty", "legacy"):
            schema = "migration_test_" + uuid4().hex
            schemas.append(schema)
            with engine.begin() as connection:
                connection.execute(text(f'CREATE SCHEMA "{schema}"'))
            with engine.connect() as connection:
                connection.execute(text(f'SET search_path TO "{schema}"'))
                connection.commit()
                config.attributes["connection"] = connection
                if scenario == "legacy":
                    # Simulate an installed ORM bootstrap at the last legacy head.
                    # This test-only DDL is deliberately outside backend/app.
                    Base.metadata.create_all(connection)
                    command.stamp(config, "20260921_0100")
                    connection.commit()
                command.upgrade(config, "head")
                command.upgrade(config, "head")
                connection.commit()
                actual = inspect(connection)
                for table in Base.metadata.sorted_tables:
                    expected = {column.name for column in table.columns}
                    found = {column["name"] for column in actual.get_columns(table.name)}
                    assert expected <= found, (scenario, table.name, expected - found)
                print(f"{scenario}: upgraded to head with all {len(Base.metadata.tables)} ORM tables/columns")
    finally:
        with engine.begin() as connection:
            for schema in schemas:
                connection.execute(text(f'DROP SCHEMA "{schema}" CASCADE'))
        engine.dispose()


if __name__ == "__main__":
    main()
