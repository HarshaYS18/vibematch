"""Inbox Service Extraction state ownership foundation

Revision ID: 20260923_0300
Revises: 20260923_0200
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "20260923_0300"
down_revision = "20260923_0200"
branch_labels = None
depends_on = None


def upgrade() -> None:
    for name in ("is_muted", "is_pinned", "is_archived"):
        op.add_column(
            "inbox_participants",
            sa.Column(name, sa.Boolean(), nullable=False, server_default=sa.false()),
        )
        op.create_index(
            f"ix_inbox_participants_{name}",
            "inbox_participants",
            [name],
            unique=False,
        )

    # Preserve the historical UI state while moving mute/pin/archive to the
    # participant, which is the correct per-user authority.
    op.execute(
        """
        UPDATE inbox_participants p
        SET is_muted = c.is_muted,
            is_pinned = c.is_pinned,
            is_archived = c.is_archived
        FROM inbox_conversations c
        WHERE c.id = p.conversation_id
        """
    )

    op.create_unique_constraint(
        "uq_inbox_participant_conversation_user",
        "inbox_participants",
        ["conversation_id", "user_id"],
    )
    op.create_index(
        "ix_inbox_participant_user_state",
        "inbox_participants",
        ["user_id", "is_archived", "is_pinned"],
        unique=False,
    )

    op.create_table(
        "inbox_read_receipts",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("message_id", sa.Integer(), nullable=False),
        sa.Column("conversation_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("read_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["message_id"], ["inbox_messages.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["conversation_id"], ["inbox_conversations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.UniqueConstraint(
            "message_id",
            "user_id",
            name="uq_inbox_read_receipt_message_user",
        ),
    )
    op.create_index("ix_inbox_read_receipts_message_id", "inbox_read_receipts", ["message_id"])
    op.create_index("ix_inbox_read_receipts_conversation_id", "inbox_read_receipts", ["conversation_id"])
    op.create_index("ix_inbox_read_receipts_user_id", "inbox_read_receipts", ["user_id"])
    op.create_index("ix_inbox_read_receipts_read_at", "inbox_read_receipts", ["read_at"])
    op.create_index(
        "ix_inbox_read_receipt_conversation_user",
        "inbox_read_receipts",
        ["conversation_id", "user_id", "message_id"],
    )

    # Backfill a conservative historical receipt set from each participant's
    # durable last-read pointer. New reads are exclusively receipt based.
    op.execute(
        """
        INSERT INTO inbox_read_receipts (message_id, conversation_id, user_id, read_at)
        SELECT m.id, m.conversation_id, p.user_id, CURRENT_TIMESTAMP
        FROM inbox_participants p
        JOIN inbox_messages m
          ON m.conversation_id = p.conversation_id
         AND p.last_read_message_id IS NOT NULL
         AND m.id <= p.last_read_message_id
         AND (m.sender_user_id IS NULL OR m.sender_user_id <> p.user_id)
        ON CONFLICT (message_id, user_id) DO NOTHING
        """
    )


def downgrade() -> None:
    raise RuntimeError(
        "Forward-only migration: Inbox per-user state/read receipts are additive ownership changes"
    )
