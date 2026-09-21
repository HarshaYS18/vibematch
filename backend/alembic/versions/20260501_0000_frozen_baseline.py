"""Create the previously implicit ORM baseline for empty PostgreSQL databases.

Existing stamped installations already descend from this revision and are
reconciled by the takeover revision. Unstamped nonempty databases must first be
audited and stamped at their actual legacy revision; never guess their version.
"""
from alembic import op
from sqlalchemy import inspect
from legacy_snapshot import MARKER, create_missing_tables

revision = "20260501_0000"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    tables = set(inspect(bind).get_table_names()) - {"alembic_version"}
    if tables:
        raise RuntimeError("Unversioned nonempty database: audit and stamp its actual legacy revision before upgrading.")
    create_missing_tables(bind)
    op.execute(f"CREATE TABLE {MARKER} (id INTEGER PRIMARY KEY)")


def downgrade():
    raise RuntimeError("The frozen baseline is irreversible. Restore a database backup.")
