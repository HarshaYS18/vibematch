from pathlib import Path

from alembic.config import Config
from alembic.runtime.migration import MigrationContext
from alembic.script import ScriptDirectory
from sqlalchemy.engine import Engine


BACKEND_DIR = Path(__file__).resolve().parents[2]


def assert_database_schema_current(engine: Engine) -> None:
    """Fail fast when the running database is not at the Alembic head."""
    alembic_config = Config(str(BACKEND_DIR / "alembic.ini"))
    script = ScriptDirectory.from_config(alembic_config)
    expected_heads = set(script.get_heads())

    with engine.connect() as connection:
        current_heads = set(MigrationContext.configure(connection).get_current_heads())

    if current_heads != expected_heads:
        expected = ", ".join(sorted(expected_heads)) or "<none>"
        current = ", ".join(sorted(current_heads)) or "<none>"
        raise RuntimeError(
            "Database schema is not current. "
            f"Expected Alembic head(s): {expected}; current: {current}. "
            "Run 'alembic upgrade head' from the backend directory before starting the API."
        )
