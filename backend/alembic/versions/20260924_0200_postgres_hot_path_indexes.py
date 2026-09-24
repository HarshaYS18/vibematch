"""Chunk 25 PostgreSQL hot-path indexes.

Revision ID: 20260924_0200
Revises: 20260924_0100
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "20260924_0200"
down_revision = "20260924_0100"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index(
        "ix_vibe_posts_live_feed_cursor",
        "vibe_posts",
        [sa.text("created_at DESC"), sa.text("id DESC")],
        unique=False,
        postgresql_where=sa.text("is_deleted IS FALSE"),
    )
    op.create_index(
        "ix_vibe_saves_user_created_post",
        "vibe_saves",
        ["user_id", sa.text("created_at DESC"), "post_id"],
        unique=False,
    )
    op.create_index(
        "ix_inbox_messages_conversation_cursor",
        "inbox_messages",
        ["conversation_id", sa.text("created_at DESC"), sa.text("id DESC")],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_inbox_messages_conversation_cursor",
        table_name="inbox_messages",
    )
    op.drop_index(
        "ix_vibe_saves_user_created_post",
        table_name="vibe_saves",
    )
    op.drop_index(
        "ix_vibe_posts_live_feed_cursor",
        table_name="vibe_posts",
    )
