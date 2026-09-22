"""add outbox publish leases and retry scheduling

Revision ID: 20260922_0120
Revises: 20260922_0110
"""

from alembic import op
import sqlalchemy as sa


revision = "20260922_0120"
down_revision = "20260922_0110"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("event_outbox", sa.Column("claimed_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("event_outbox", sa.Column("claimed_by", sa.String(length=120), nullable=True))
    op.add_column("event_outbox", sa.Column("next_attempt_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("event_outbox", sa.Column("last_error", sa.String(length=500), nullable=True))
    op.create_index("ix_event_outbox_next_attempt_at", "event_outbox", ["next_attempt_at"])
    op.create_index(
        "ix_event_outbox_publish_claim",
        "event_outbox",
        ["published_at", "next_attempt_at", "claimed_at"],
    )


def downgrade() -> None:
    raise RuntimeError("Forward-only migration: retaining outbox delivery state is required")
