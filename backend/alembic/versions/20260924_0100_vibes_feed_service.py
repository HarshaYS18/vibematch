"""Chunk 24 Vibes feed counters and cursor index.

Revision ID: 20260924_0100
Revises: 20260923_0310
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "20260924_0100"
down_revision = "20260923_0310"
branch_labels = None
depends_on = None


_COUNTERS = (
    ("likes_count", "vibe_reactions", "TRUE"),
    ("comments_count", "vibe_comments", "NOT is_deleted"),
    ("shares_count", "vibe_shares", "TRUE"),
    ("saves_count", "vibe_saves", "TRUE"),
    ("reports_count", "vibe_reports", "TRUE"),
)


def upgrade() -> None:
    for column, _table, _where in _COUNTERS:
        op.add_column(
            "vibe_posts",
            sa.Column(column, sa.Integer(), nullable=False, server_default="0"),
        )

    for column, table, predicate in _COUNTERS:
        op.execute(
            f"""
            UPDATE vibe_posts p
            SET {column} = counts.total
            FROM (
                SELECT post_id, CAST(COUNT(*) AS INTEGER) AS total
                FROM {table}
                WHERE {predicate}
                GROUP BY post_id
            ) counts
            WHERE counts.post_id = p.id
            """
        )

    op.create_index(
        "ix_vibe_posts_feed_cursor",
        "vibe_posts",
        ["created_at", "id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_vibe_posts_feed_cursor", table_name="vibe_posts")
    for column, _table, _where in reversed(_COUNTERS):
        op.drop_column("vibe_posts", column)
