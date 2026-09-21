"""add room background and announcement fields

Revision ID: 20260512_room_custom
Revises: eeeb28fa72a4
Create Date: 2026-05-12
"""

from alembic import op
from legacy_snapshot import is_fresh_bootstrap, create_table, add_column, create_index
import sqlalchemy as sa


revision = "20260512_room_custom"
down_revision = "eeeb28fa72a4"
branch_labels = None
depends_on = None


def upgrade() -> None:
    if is_fresh_bootstrap(op.get_bind()):
        return
    add_column(
        "rooms",
        sa.Column(
            "background_theme_id",
            sa.String(length=80),
            nullable=False,
            server_default="default",
        ),
    )
    add_column("rooms", sa.Column("announcement_text", sa.Text(), nullable=True))
    add_column("rooms", sa.Column("announcement_updated_at", sa.DateTime(), nullable=True))
    add_column("rooms", sa.Column("announcement_updated_by_user_id", sa.Integer(), nullable=True))
    create_index("ix_rooms_background_theme_id", "rooms", ["background_theme_id"])


def downgrade() -> None:
    op.drop_index("ix_rooms_background_theme_id", table_name="rooms")
    op.drop_column("rooms", "announcement_updated_by_user_id")
    op.drop_column("rooms", "announcement_updated_at")
    op.drop_column("rooms", "announcement_text")
    op.drop_column("rooms", "background_theme_id")
