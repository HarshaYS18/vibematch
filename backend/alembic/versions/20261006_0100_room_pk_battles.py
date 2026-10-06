"""Add durable Room-vs-Room PK battle state.

Revision ID: 20261006_0100
Revises: 20260926_0100
"""
from alembic import op
import sqlalchemy as sa


revision = "20261006_0100"
down_revision = "20260926_0100"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "room_pk_matches",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("match_public_id", sa.String(length=80), nullable=False),
        sa.Column("challenger_room_id", sa.Integer(), nullable=False),
        sa.Column("opponent_room_id", sa.Integer(), nullable=False),
        sa.Column("created_by_user_id", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("duration_seconds", sa.Integer(), nullable=False),
        sa.Column("challenger_score", sa.BigInteger(), nullable=False),
        sa.Column("opponent_score", sa.BigInteger(), nullable=False),
        sa.Column("winner_room_id", sa.Integer(), nullable=True),
        sa.Column("challenge_expires_at", sa.DateTime(), nullable=False),
        sa.Column("started_at", sa.DateTime(), nullable=True),
        sa.Column("ends_at", sa.DateTime(), nullable=True),
        sa.Column("finished_at", sa.DateTime(), nullable=True),
        sa.Column("finished_reason", sa.String(length=80), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["challenger_room_id"], ["rooms.id"]),
        sa.ForeignKeyConstraint(["opponent_room_id"], ["rooms.id"]),
        sa.ForeignKeyConstraint(["winner_room_id"], ["rooms.id"]),
        sa.ForeignKeyConstraint(["created_by_user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_room_pk_matches_match_public_id", "room_pk_matches", ["match_public_id"], unique=True)
    op.create_index("ix_room_pk_matches_challenger_room_id", "room_pk_matches", ["challenger_room_id"])
    op.create_index("ix_room_pk_matches_opponent_room_id", "room_pk_matches", ["opponent_room_id"])
    op.create_index("ix_room_pk_matches_created_by_user_id", "room_pk_matches", ["created_by_user_id"])
    op.create_index("ix_room_pk_matches_status", "room_pk_matches", ["status"])

    op.create_table(
        "room_pk_score_receipts",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("match_id", sa.Integer(), nullable=False),
        sa.Column("room_id", sa.Integer(), nullable=False),
        sa.Column("source_event_id", sa.String(length=160), nullable=False),
        sa.Column("coin_value", sa.BigInteger(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["match_id"], ["room_pk_matches.id"]),
        sa.ForeignKeyConstraint(["room_id"], ["rooms.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("source_event_id", name="uq_room_pk_score_receipt_event"),
    )
    op.create_index("ix_room_pk_score_receipts_match_id", "room_pk_score_receipts", ["match_id"])
    op.create_index("ix_room_pk_score_receipts_room_id", "room_pk_score_receipts", ["room_id"])


def downgrade() -> None:
    op.drop_index("ix_room_pk_score_receipts_room_id", table_name="room_pk_score_receipts")
    op.drop_index("ix_room_pk_score_receipts_match_id", table_name="room_pk_score_receipts")
    op.drop_table("room_pk_score_receipts")
    op.drop_index("ix_room_pk_matches_status", table_name="room_pk_matches")
    op.drop_index("ix_room_pk_matches_created_by_user_id", table_name="room_pk_matches")
    op.drop_index("ix_room_pk_matches_opponent_room_id", table_name="room_pk_matches")
    op.drop_index("ix_room_pk_matches_challenger_room_id", table_name="room_pk_matches")
    op.drop_index("ix_room_pk_matches_match_public_id", table_name="room_pk_matches")
    op.drop_table("room_pk_matches")
