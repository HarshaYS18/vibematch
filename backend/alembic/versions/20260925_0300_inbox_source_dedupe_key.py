"""Add idempotent source key to Inbox messages.

Revision ID: 20260925_0300
Revises: 20260925_0200
"""
from alembic import op
import sqlalchemy as sa


revision = "20260925_0300"
down_revision = "20260925_0200"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "inbox_messages",
        sa.Column("source_dedupe_key", sa.String(length=180), nullable=True),
    )
    op.create_unique_constraint(
        "uq_inbox_messages_source_dedupe_key",
        "inbox_messages",
        ["source_dedupe_key"],
    )
    op.create_index(
        "ix_inbox_messages_source_dedupe_key",
        "inbox_messages",
        ["source_dedupe_key"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_inbox_messages_source_dedupe_key",
        table_name="inbox_messages",
    )
    op.drop_constraint(
        "uq_inbox_messages_source_dedupe_key",
        "inbox_messages",
        type_="unique",
    )
    op.drop_column("inbox_messages", "source_dedupe_key")
