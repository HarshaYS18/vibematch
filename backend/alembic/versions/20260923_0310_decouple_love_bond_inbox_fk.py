"""decouple love bond requests from Inbox table ownership

Revision ID: 20260923_0310
Revises: 20260923_0300
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "20260923_0310"
down_revision = "20260923_0300"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "love_bond_requests",
        sa.Column("inbox_message_public_id", sa.String(length=100), nullable=True),
    )
    op.create_index(
        "ix_love_bond_requests_inbox_message_public_id",
        "love_bond_requests",
        ["inbox_message_public_id"],
        unique=False,
    )
    op.execute(
        """
        UPDATE love_bond_requests r
        SET inbox_message_public_id = m.public_id
        FROM inbox_messages m
        WHERE r.inbox_message_id = m.id
          AND r.inbox_message_public_id IS NULL
        """
    )

    # Cross-domain numeric FKs would force Profile/Social credentials to retain
    # direct access to Inbox-owned tables. Public IDs become the service
    # contract boundary instead.
    op.execute(
        """
        ALTER TABLE love_bond_requests
        DROP CONSTRAINT IF EXISTS love_bond_requests_inbox_message_id_fkey
        """
    )
    op.execute("DROP INDEX IF EXISTS ix_love_bond_requests_inbox_message_id")
    op.drop_column("love_bond_requests", "inbox_message_id")


def downgrade() -> None:
    raise RuntimeError(
        "Forward-only migration: love bond requests now reference Inbox by public service ID"
    )
