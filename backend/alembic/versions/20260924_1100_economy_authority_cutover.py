"""Complete Economy authority cutover accounting foundation.

Revision ID: 20260924_1100
Revises: 20260924_1000
"""
from alembic import op
import sqlalchemy as sa

revision = "20260924_1100"
down_revision = "20260924_1000"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "economy_journal_entries",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("economy_transaction_id", sa.Integer(), nullable=False),
        sa.Column("transaction_id", sa.String(length=36), nullable=False),
        sa.Column("business_reference", sa.String(length=200), nullable=False),
        sa.Column("currency_type", sa.String(length=20), nullable=False),
        sa.Column("account_code", sa.String(length=160), nullable=False),
        sa.Column("direction", sa.String(length=10), nullable=False),
        sa.Column("amount", sa.BigInteger(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=True),
        sa.Column("source_type", sa.String(length=80), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint("amount > 0", name="ck_economy_journal_positive_amount"),
        sa.CheckConstraint(
            "direction IN ('DEBIT','CREDIT')",
            name="ck_economy_journal_direction",
        ),
        sa.ForeignKeyConstraint(
            ["economy_transaction_id"],
            ["economy_transactions.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    for column in (
        "economy_transaction_id",
        "transaction_id",
        "business_reference",
        "currency_type",
        "account_code",
        "direction",
        "user_id",
        "source_type",
        "created_at",
    ):
        op.create_index(
            f"ix_economy_journal_entries_{column}",
            "economy_journal_entries",
            [column],
        )


def downgrade() -> None:
    op.drop_table("economy_journal_entries")
