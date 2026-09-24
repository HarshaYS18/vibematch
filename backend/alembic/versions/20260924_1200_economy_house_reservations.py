"""Durable Economy house reservations and reconciliation ownership.

Revision ID: 20260924_1200
Revises: 20260924_1100
"""
from alembic import op
import sqlalchemy as sa

revision = "20260924_1200"
down_revision = "20260924_1100"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "economy_house_reservations",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("reservation_key", sa.String(length=220), nullable=False),
        sa.Column("release_scope", sa.String(length=220), nullable=False),
        sa.Column("pool_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=True),
        sa.Column("amount", sa.BigInteger(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="ACTIVE"),
        sa.Column("reference_type", sa.String(length=80), nullable=False),
        sa.Column("reference_id", sa.String(length=220), nullable=True),
        sa.Column("transaction_id", sa.String(length=36), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("released_at", sa.DateTime(), nullable=True),
        sa.CheckConstraint("amount > 0", name="ck_economy_house_reservation_positive_amount"),
        sa.CheckConstraint(
            "status IN ('ACTIVE','RELEASED')",
            name="ck_economy_house_reservation_status",
        ),
        sa.ForeignKeyConstraint(["pool_id"], ["game_pools.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("reservation_key", name="uq_economy_house_reservation_key"),
    )
    for column in (
        "reservation_key",
        "release_scope",
        "pool_id",
        "user_id",
        "status",
        "reference_type",
        "reference_id",
        "transaction_id",
        "created_at",
        "released_at",
    ):
        op.create_index(
            f"ix_economy_house_reservations_{column}",
            "economy_house_reservations",
            [column],
        )


def downgrade() -> None:
    op.drop_table("economy_house_reservations")
