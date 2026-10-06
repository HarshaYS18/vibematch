"""Add retry identity to normalized Cricket ball events.

Revision ID: 20260925_0400
Revises: 20260925_0300
"""
from alembic import op
import sqlalchemy as sa


revision = "20260925_0400"
down_revision = "20260925_0300"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "cricket_ball_events",
        sa.Column("source_event_id", sa.String(length=80), nullable=True),
    )
    op.create_unique_constraint(
        "uq_cricket_ball_event_match_source",
        "cricket_ball_events",
        ["match_id", "source_event_id"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "uq_cricket_ball_event_match_source",
        "cricket_ball_events",
        type_="unique",
    )
    op.drop_column("cricket_ball_events", "source_event_id")
