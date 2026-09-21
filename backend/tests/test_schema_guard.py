from pathlib import Path
from unittest import TestCase

from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine, text
from app.core.schema_guard import assert_database_schema_current


class SchemaGuardTests(TestCase):
    def test_single_head_and_migration_required(self):
        config = Config(str(Path(__file__).resolve().parents[1] / "alembic.ini"))
        heads = ScriptDirectory.from_config(config).get_heads()
        self.assertEqual(len(heads), 1)
        engine = create_engine("sqlite://")
        with self.assertRaisesRegex(RuntimeError, "alembic upgrade head"):
            assert_database_schema_current(engine)
        with engine.begin() as connection:
            connection.execute(text("CREATE TABLE alembic_version (version_num VARCHAR(32) PRIMARY KEY)"))
            connection.execute(text("INSERT INTO alembic_version VALUES (:head)"), {"head": heads[0]})
        assert_database_schema_current(engine)
        engine.dispose()
