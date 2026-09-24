"""Chunk 27 Identity/Profile-Social durable session foundation.

Revision ID: 20260924_0300
Revises: 20260924_0200
"""
from alembic import op
import sqlalchemy as sa

revision = "20260924_0300"
down_revision = "20260924_0200"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "identity_devices",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("device_id", sa.String(length=255), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("first_seen_at", sa.DateTime(), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(), nullable=False),
        sa.Column("last_login_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "device_id", name="uq_identity_device_user_device"),
    )
    op.create_index("ix_identity_devices_user_id", "identity_devices", ["user_id"])
    op.create_index("ix_identity_devices_device_id", "identity_devices", ["device_id"])
    op.create_index("ix_identity_devices_is_active", "identity_devices", ["is_active"])

    op.create_table(
        "identity_sessions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("session_id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("device_id", sa.String(length=255), nullable=True),
        sa.Column("token_version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("issued_at", sa.DateTime(), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("revoked_at", sa.DateTime(), nullable=True),
        sa.Column("revoke_reason", sa.String(length=120), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_identity_sessions_session_id", "identity_sessions", ["session_id"], unique=True)
    op.create_index("ix_identity_sessions_user_id", "identity_sessions", ["user_id"])
    op.create_index("ix_identity_sessions_device_id", "identity_sessions", ["device_id"])
    op.create_index("ix_identity_sessions_expires_at", "identity_sessions", ["expires_at"])
    op.create_index("ix_identity_sessions_revoked_at", "identity_sessions", ["revoked_at"])
    op.create_index("ix_identity_sessions_is_active", "identity_sessions", ["is_active"])


def downgrade() -> None:
    op.drop_table("identity_sessions")
    op.drop_table("identity_devices")
