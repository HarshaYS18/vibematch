"""Idempotent gift EXP projection receipts.

Revision ID: 20260924_0600
Revises: 20260924_0500
"""
from alembic import op
import sqlalchemy as sa

revision = "20260924_0600"
down_revision = "20260924_0500"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "experience_mutation_receipts",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("receipt_key", sa.String(length=180), nullable=False),
        sa.Column("source_type", sa.String(length=80), nullable=False),
        sa.Column("source_id", sa.String(length=120), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("receipt_key"),
    )
    op.create_index(
        "ix_experience_mutation_receipts_receipt_key",
        "experience_mutation_receipts",
        ["receipt_key"],
        unique=True,
    )
    op.create_index(
        "ix_experience_mutation_receipts_source_type",
        "experience_mutation_receipts",
        ["source_type"],
    )
    op.create_index(
        "ix_experience_mutation_receipts_source_id",
        "experience_mutation_receipts",
        ["source_id"],
    )


def downgrade() -> None:
    op.drop_table("experience_mutation_receipts")
