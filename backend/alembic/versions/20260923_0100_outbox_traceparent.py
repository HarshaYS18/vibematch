"""add W3C trace context to durable outbox

Revision ID: 20260923_0100
Revises: 20260922_0120
"""

from alembic import op
import sqlalchemy as sa


revision = "20260923_0100"
down_revision = "20260922_0120"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("event_outbox", sa.Column("traceparent", sa.String(length=255), nullable=True))


def downgrade() -> None:
    raise RuntimeError("Forward-only migration: retaining event trace context is safe and additive")
