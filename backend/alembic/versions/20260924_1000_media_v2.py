"""Media v2 direct upload sessions, variants and processing state.

Revision ID: 20260924_1000
Revises: 20260924_0900
"""
from alembic import op
import sqlalchemy as sa

revision = "20260924_1000"
down_revision = "20260924_0900"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "cdn_media_assets",
        sa.Column(
            "processing_status",
            sa.String(length=50),
            nullable=False,
            server_default="not_required",
        ),
    )
    op.add_column("cdn_media_assets", sa.Column("processing_error", sa.Text(), nullable=True))
    op.add_column("cdn_media_assets", sa.Column("processing_started_at", sa.DateTime(), nullable=True))
    op.add_column("cdn_media_assets", sa.Column("processing_completed_at", sa.DateTime(), nullable=True))
    op.create_index("ix_cdn_media_assets_processing_status", "cdn_media_assets", ["processing_status"], unique=False)

    op.create_table(
        "media_upload_sessions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("public_id", sa.String(length=100), nullable=False),
        sa.Column("media_id", sa.Integer(), nullable=False),
        sa.Column("owner_user_id", sa.Integer(), nullable=False),
        sa.Column("purpose", sa.String(length=50), nullable=False),
        sa.Column("original_filename", sa.String(length=255), nullable=False),
        sa.Column("expected_mime_type", sa.String(length=120), nullable=False),
        sa.Column("expected_size_bytes", sa.BigInteger(), nullable=False),
        sa.Column("object_key", sa.String(length=700), nullable=False),
        sa.Column("storage_driver", sa.String(length=30), nullable=False),
        sa.Column("upload_mode", sa.String(length=30), nullable=False),
        sa.Column("storage_upload_id", sa.String(length=1000), nullable=True),
        sa.Column("part_size_bytes", sa.BigInteger(), nullable=True),
        sa.Column("part_count", sa.Integer(), nullable=True),
        sa.Column("status", sa.String(length=30), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("completed_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["media_id"], ["cdn_media_assets.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["owner_user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("media_id"),
        sa.UniqueConstraint("object_key"),
        sa.UniqueConstraint("public_id"),
    )
    for column in ("public_id", "media_id", "owner_user_id", "purpose", "object_key", "status", "expires_at"):
        op.create_index(f"ix_media_upload_sessions_{column}", "media_upload_sessions", [column], unique=column in {"public_id", "media_id", "object_key"})

    op.create_table(
        "cdn_media_variants",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("media_id", sa.Integer(), nullable=False),
        sa.Column("variant_key", sa.String(length=80), nullable=False),
        sa.Column("kind", sa.String(length=40), nullable=False),
        sa.Column("object_key", sa.String(length=700), nullable=False),
        sa.Column("public_url", sa.String(length=900), nullable=False),
        sa.Column("mime_type", sa.String(length=120), nullable=False),
        sa.Column("width", sa.Integer(), nullable=True),
        sa.Column("height", sa.Integer(), nullable=True),
        sa.Column("bitrate_kbps", sa.Integer(), nullable=True),
        sa.Column("size_bytes", sa.BigInteger(), nullable=False),
        sa.Column("duration_ms", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["media_id"], ["cdn_media_assets.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("object_key"),
    )
    op.create_index("ix_cdn_media_variants_id", "cdn_media_variants", ["id"], unique=False)
    op.create_index("ix_cdn_media_variants_media_id", "cdn_media_variants", ["media_id"], unique=False)
    op.create_index("ix_cdn_media_variants_object_key", "cdn_media_variants", ["object_key"], unique=True)
    op.create_index("ix_cdn_media_variants_created_at", "cdn_media_variants", ["created_at"], unique=False)
    op.create_index(
        "uq_cdn_media_variants_media_key",
        "cdn_media_variants",
        ["media_id", "variant_key"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_table("cdn_media_variants")
    op.drop_table("media_upload_sessions")
    op.drop_index("ix_cdn_media_assets_processing_status", table_name="cdn_media_assets")
    op.drop_column("cdn_media_assets", "processing_completed_at")
    op.drop_column("cdn_media_assets", "processing_started_at")
    op.drop_column("cdn_media_assets", "processing_error")
    op.drop_column("cdn_media_assets", "processing_status")
