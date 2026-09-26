"""Durable resumable Economy bulk grants.

Revision ID: 20260924_0700
Revises: 20260924_0600
"""
from alembic import op
import sqlalchemy as sa

revision = "20260924_0700"
down_revision = "20260924_0600"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "economy_bulk_grants",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("grant_id", sa.String(length=36), nullable=False),
        sa.Column("idempotency_key", sa.String(length=160), nullable=False),
        sa.Column("request_hash", sa.String(length=64), nullable=False),
        sa.Column("actor_user_id", sa.Integer(), nullable=False),
        sa.Column("coin_amount", sa.BigInteger(), nullable=False),
        sa.Column("active_only", sa.Boolean(), nullable=False),
        sa.Column("reason", sa.String(length=255), nullable=False),
        sa.Column("status", sa.String(length=30), nullable=False, server_default="PENDING"),
        sa.Column("max_user_id", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("last_user_id", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("eligible_count", sa.BigInteger(), nullable=False, server_default="0"),
        sa.Column("processed_count", sa.BigInteger(), nullable=False, server_default="0"),
        sa.Column("failure_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("lease_owner", sa.String(length=160), nullable=True),
        sa.Column("lease_until", sa.DateTime(), nullable=True),
        sa.Column("next_attempt_at", sa.DateTime(), nullable=True),
        sa.Column("last_error", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("completed_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("grant_id"),
        sa.UniqueConstraint("idempotency_key"),
    )
    for column in (
        "grant_id", "idempotency_key", "actor_user_id", "status", "lease_owner",
        "lease_until", "next_attempt_at", "created_at", "completed_at",
    ):
        op.create_index(
            f"ix_economy_bulk_grants_{column}",
            "economy_bulk_grants",
            [column],
        )

    op.create_table(
        "economy_bulk_grant_recipients",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("grant_id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("amount", sa.BigInteger(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "grant_id",
            "user_id",
            name="uq_economy_bulk_grant_recipient",
        ),
    )
    for column in ("grant_id", "user_id", "created_at"):
        op.create_index(
            f"ix_economy_bulk_grant_recipients_{column}",
            "economy_bulk_grant_recipients",
            [column],
        )


def downgrade() -> None:
    op.drop_table("economy_bulk_grant_recipients")
    op.drop_table("economy_bulk_grants")
