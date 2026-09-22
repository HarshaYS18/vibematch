"""add transactional event outbox and worker idempotency records

Revision ID: 20260922_0100
Revises: 20260921_0120
"""

from alembic import op
import sqlalchemy as sa


revision = "20260922_0100"
down_revision = "20260921_0120"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "event_outbox",
        sa.Column("event_id", sa.String(length=36), primary_key=True),
        sa.Column("event_type", sa.String(length=100), nullable=False),
        sa.Column("event_version", sa.Integer(), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("request_id", sa.String(length=64), nullable=True),
        sa.Column("trace_id", sa.String(length=64), nullable=True),
        sa.Column("actor_user_id", sa.Integer(), nullable=True),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("attempt_count", sa.Integer(), nullable=False),
    )
    op.create_index("ix_event_outbox_event_type", "event_outbox", ["event_type"])
    op.create_index("ix_event_outbox_published_at", "event_outbox", ["published_at"])
    op.create_table(
        "worker_processed_events",
        sa.Column("event_id", sa.String(length=36), primary_key=True),
        sa.Column("handler", sa.String(length=100), primary_key=True),
        sa.Column("processed_at", sa.DateTime(timezone=True), nullable=False),
    )


def downgrade() -> None:
    raise RuntimeError("Forward-only migration: retaining published event and idempotency history is required")
