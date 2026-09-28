"""Store purchase saga identity and reconciliation state.

Revision ID: 20260924_0500
Revises: 20260924_0400
"""
from alembic import op
import sqlalchemy as sa

revision = "20260924_0500"
down_revision = "20260924_0400"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "store_purchase_operations",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("purchase_id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("item_id", sa.String(length=120), nullable=False),
        sa.Column("status", sa.String(length=40), nullable=False, server_default="PENDING"),
        sa.Column("economy_transaction_id", sa.String(length=36), nullable=True),
        sa.Column("compensation_transaction_id", sa.String(length=36), nullable=True),
        sa.Column("attempt_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("lease_until", sa.DateTime(), nullable=True),
        sa.Column("error_detail", sa.String(length=700), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("purchase_id"),
    )
    for column in (
        "purchase_id", "user_id", "item_id", "status",
        "economy_transaction_id", "compensation_transaction_id", "lease_until",
    ):
        op.create_index(
            f"ix_store_purchase_operations_{column}",
            "store_purchase_operations",
            [column],
        )


def downgrade() -> None:
    op.drop_table("store_purchase_operations")
