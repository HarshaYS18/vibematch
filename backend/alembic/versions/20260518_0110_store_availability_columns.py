"""add store item availability windows

Revision ID: 20260518_0110
Revises: 20260518_0100
Create Date: 2026-05-18 01:10:00.000000
"""

from alembic import op
from legacy_snapshot import is_fresh_bootstrap, create_table, add_column, create_index
import sqlalchemy as sa


revision = "20260518_0110"
down_revision = "20260518_0100"
branch_labels = None
depends_on = None


def upgrade() -> None:
    if is_fresh_bootstrap(op.get_bind()):
        return
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        op.execute("ALTER TABLE store_items ADD COLUMN IF NOT EXISTS availability_starts_at TIMESTAMP")
        op.execute("ALTER TABLE store_items ADD COLUMN IF NOT EXISTS availability_ends_at TIMESTAMP")
        return
    add_column("store_items", sa.Column("availability_starts_at", sa.DateTime(), nullable=True))
    add_column("store_items", sa.Column("availability_ends_at", sa.DateTime(), nullable=True))


def downgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        op.execute("ALTER TABLE store_items DROP COLUMN IF EXISTS availability_ends_at")
        op.execute("ALTER TABLE store_items DROP COLUMN IF EXISTS availability_starts_at")
        return
    op.drop_column("store_items", "availability_ends_at")
    op.drop_column("store_items", "availability_starts_at")
