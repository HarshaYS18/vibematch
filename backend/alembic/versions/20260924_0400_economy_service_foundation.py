"""Restore Chunk 25 Economy transaction foundation.

Revision ID: 20260924_0400
Revises: 20260924_0300
"""
from alembic import op
import sqlalchemy as sa

revision = "20260924_0400"
down_revision = "20260924_0300"
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.create_table(
        "economy_transactions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("transaction_id", sa.String(length=36), nullable=False),
        sa.Column("idempotency_key", sa.String(length=160), nullable=False),
        sa.Column("business_reference", sa.String(length=200), nullable=False),
        sa.Column("operation_type", sa.String(length=80), nullable=False),
        sa.Column("request_hash", sa.String(length=64), nullable=False),
        sa.Column("status", sa.String(length=30), nullable=False, server_default="PENDING"),
        sa.Column("actor_user_id", sa.Integer(), nullable=True),
        sa.Column("result_json", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("completed_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("transaction_id"),
        sa.UniqueConstraint("idempotency_key"),
    )
    for column in ("transaction_id","idempotency_key","business_reference","operation_type","status","actor_user_id","created_at","completed_at"):
        op.create_index(f"ix_economy_transactions_{column}", "economy_transactions", [column])
    op.add_column("wallet_ledger", sa.Column("transaction_id", sa.String(length=36), nullable=True))
    op.add_column("wallet_ledger", sa.Column("idempotency_key", sa.String(length=160), nullable=True))
    op.add_column("wallet_ledger", sa.Column("business_reference", sa.String(length=200), nullable=True))
    op.create_index("ix_wallet_ledger_transaction_id", "wallet_ledger", ["transaction_id"])
    op.create_index("ix_wallet_ledger_idempotency_key", "wallet_ledger", ["idempotency_key"])
    op.create_index("ix_wallet_ledger_business_reference", "wallet_ledger", ["business_reference"])

def downgrade() -> None:
    op.drop_index("ix_wallet_ledger_business_reference", table_name="wallet_ledger")
    op.drop_index("ix_wallet_ledger_idempotency_key", table_name="wallet_ledger")
    op.drop_index("ix_wallet_ledger_transaction_id", table_name="wallet_ledger")
    op.drop_column("wallet_ledger", "business_reference")
    op.drop_column("wallet_ledger", "idempotency_key")
    op.drop_column("wallet_ledger", "transaction_id")
    op.drop_table("economy_transactions")
