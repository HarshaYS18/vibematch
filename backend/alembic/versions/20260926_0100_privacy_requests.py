"""Add Identity-owned privacy request workflow.

Revision ID: 20260926_0100
Revises: 20260925_0400
"""
from alembic import op
import sqlalchemy as sa


revision = "20260926_0100"
down_revision = "20260925_0400"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "privacy_requests",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("public_user_id", sa.BigInteger(), nullable=False),
        sa.Column("request_type", sa.String(length=20), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("requested_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("due_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_privacy_requests_user_id", "privacy_requests", ["user_id"])
    op.create_index("ix_privacy_requests_public_user_id", "privacy_requests", ["public_user_id"])
    op.create_index("ix_privacy_requests_status", "privacy_requests", ["status"])


def downgrade() -> None:
    op.drop_index("ix_privacy_requests_status", table_name="privacy_requests")
    op.drop_index("ix_privacy_requests_public_user_id", table_name="privacy_requests")
    op.drop_index("ix_privacy_requests_user_id", table_name="privacy_requests")
    op.drop_table("privacy_requests")
