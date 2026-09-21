"""add room cover photo url

Revision ID: 20260513_0100
Revises: 
Create Date: 2026-05-13 01:00:00.000000
"""

from alembic import op
from legacy_snapshot import is_fresh_bootstrap, create_table, add_column, create_index
import sqlalchemy as sa


revision = "20260513_0100"
down_revision = "20260501_0000"
branch_labels = None
depends_on = None


def upgrade() -> None:
    if is_fresh_bootstrap(op.get_bind()):
        return
    add_column("rooms", sa.Column("cover_photo_url", sa.String(length=500), nullable=True))


def downgrade() -> None:
    op.drop_column("rooms", "cover_photo_url")
