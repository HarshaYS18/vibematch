"""Add Economy-owned manual VIP override authority.

Revision ID: 20260925_0200
Revises: 20260925_0100
"""
from alembic import op
import sqlalchemy as sa


revision = "20260925_0200"
down_revision = "20260925_0100"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "user_vip_overrides",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("vip_level", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("svip_level", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("vip_is_active", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("svip_is_active", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("svip_expires_at", sa.DateTime(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("updated_by_user_id", sa.Integer(), nullable=True),
        sa.Column("update_reason", sa.String(length=255), nullable=True),
        sa.Column("last_transaction_id", sa.String(length=36), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["updated_by_user_id"],
            ["users.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_user_vip_overrides_id",
        "user_vip_overrides",
        ["id"],
    )
    op.create_index(
        "ix_user_vip_overrides_user_id",
        "user_vip_overrides",
        ["user_id"],
        unique=True,
    )
    op.create_index(
        "ix_user_vip_overrides_created_at",
        "user_vip_overrides",
        ["created_at"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_user_vip_overrides_created_at",
        table_name="user_vip_overrides",
    )
    op.drop_index(
        "ix_user_vip_overrides_user_id",
        table_name="user_vip_overrides",
    )
    op.drop_index(
        "ix_user_vip_overrides_id",
        table_name="user_vip_overrides",
    )
    op.drop_table("user_vip_overrides")
