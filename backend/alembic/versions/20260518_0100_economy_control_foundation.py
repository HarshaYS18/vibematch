"""economy control center source of truth foundation

Revision ID: 20260518_0100
Revises: 20260517_0100
Create Date: 2026-05-18 01:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "20260518_0100"
down_revision = "20260517_0100"
branch_labels = None
depends_on = None


SPECIAL_PERMISSION_VALUES = [
    "ROOM_FORCE_JOIN",
    "ROOM_LOCK_OVERRIDE",
    "SECRET_VIBE_OVERRIDE",
    "MANAGE_STORE_CATALOG",
    "MANAGE_ASSETS",
    "MANAGE_ECONOMY_RULES",
    "MANAGE_VIP_RULES",
    "MANAGE_SVIP_RULES",
    "MANAGE_LEVEL_RULES",
    "MANAGE_ROLES",
    "MANAGE_PERMISSIONS",
    "GRANT_STEALTH",
    "USE_STEALTH",
    "MANAGE_ROOM_PRIVACY",
    "MANAGE_ROOM_ASSETS",
    "MANAGE_GIFTS",
    "MANAGE_GIFT_CATEGORIES",
]


def upgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        for value in SPECIAL_PERMISSION_VALUES:
            op.execute(f"ALTER TYPE specialpermissionname ADD VALUE IF NOT EXISTS '{value}'")

    op.create_table(
        "economy_rule_sets",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("track_key", sa.String(length=40), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("title", sa.String(length=140), nullable=False),
        sa.Column("max_level", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("curve_type", sa.String(length=40), nullable=False, server_default="explicit_threshold_table"),
        sa.Column("curve_exponent", sa.String(length=40), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("is_published", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("rule_payload_json", sa.JSON(), nullable=True),
        sa.Column("created_by_user_id", sa.Integer(), nullable=True),
        sa.Column("updated_by_user_id", sa.Integer(), nullable=True),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["created_by_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["updated_by_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("track_key", "version", name="uq_economy_rule_set_track_version"),
    )
    op.create_index("ix_economy_rule_sets_track_key", "economy_rule_sets", ["track_key"])
    op.create_index("ix_economy_rule_sets_is_active", "economy_rule_sets", ["is_active"])
    op.create_index("ix_economy_rule_sets_is_published", "economy_rule_sets", ["is_published"])

    op.create_table(
        "economy_rule_levels",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("rule_set_id", sa.Integer(), nullable=False),
        sa.Column("level", sa.Integer(), nullable=False),
        sa.Column("required_exp", sa.BigInteger(), nullable=False, server_default="0"),
        sa.Column("required_coin_value", sa.BigInteger(), nullable=False, server_default="0"),
        sa.Column("reward_payload_json", sa.JSON(), nullable=True),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["rule_set_id"], ["economy_rule_sets.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("rule_set_id", "level", name="uq_economy_rule_level_set_level"),
    )
    op.create_index("ix_economy_rule_levels_rule_set_id", "economy_rule_levels", ["rule_set_id"])
    op.create_index("ix_economy_rule_levels_level", "economy_rule_levels", ["level"])

    op.create_table(
        "store_categories",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("category_key", sa.String(length=80), nullable=False),
        sa.Column("label", sa.String(length=140), nullable=False),
        sa.Column("description", sa.String(length=400), nullable=True),
        sa.Column("visibility", sa.String(length=40), nullable=False, server_default="public"),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("is_system", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_by_user_id", sa.Integer(), nullable=True),
        sa.Column("updated_by_user_id", sa.Integer(), nullable=True),
        sa.Column("reason", sa.String(length=255), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("category_key"),
    )
    op.create_index("ix_store_categories_category_key", "store_categories", ["category_key"])
    op.create_index("ix_store_categories_is_active", "store_categories", ["is_active"])

    for column in [
        sa.Column("item_type", sa.String(length=60), nullable=False, server_default="store_item"),
        sa.Column("currency_type", sa.String(length=30), nullable=False, server_default="coin"),
        sa.Column("ownership_type", sa.String(length=40), nullable=False, server_default="permanent"),
        sa.Column("duration_days", sa.Integer(), nullable=True),
        sa.Column("cdn_asset_url", sa.String(length=700), nullable=True),
        sa.Column("thumbnail_url", sa.String(length=700), nullable=True),
        sa.Column("animation_url", sa.String(length=700), nullable=True),
        sa.Column("video_url", sa.String(length=700), nullable=True),
        sa.Column("visibility", sa.String(length=40), nullable=False, server_default="public"),
        sa.Column("vip_required_level", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("svip_required_level", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("official_only", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("asset_version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("cache_key", sa.String(length=120), nullable=True),
        sa.Column("catalog_version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("admin_notes", sa.Text(), nullable=True),
    ]:
        op.add_column("store_items", column)

    op.add_column("user_store_inventory", sa.Column("ownership_type", sa.String(length=40), nullable=False, server_default="purchase"))
    op.add_column("user_store_inventory", sa.Column("granted_by_user_id", sa.Integer(), nullable=True))
    op.create_index("ix_user_store_inventory_granted_by_user_id", "user_store_inventory", ["granted_by_user_id"])

    op.create_table(
        "store_asset_manifests",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("manifest_key", sa.String(length=120), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("status", sa.String(length=30), nullable=False, server_default="draft"),
        sa.Column("raw_payload_json", sa.JSON(), nullable=False),
        sa.Column("validation_errors_json", sa.JSON(), nullable=True),
        sa.Column("created_by_user_id", sa.Integer(), nullable=True),
        sa.Column("published_by_user_id", sa.Integer(), nullable=True),
        sa.Column("reason", sa.String(length=255), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("published_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_store_asset_manifests_manifest_key", "store_asset_manifests", ["manifest_key"])
    op.create_index("ix_store_asset_manifests_status", "store_asset_manifests", ["status"])

    op.create_table(
        "user_stealth_states",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("is_enabled", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("granted_by_user_id", sa.Integer(), nullable=True),
        sa.Column("grant_reason", sa.Text(), nullable=True),
        sa.Column("toggle_reason", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["granted_by_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id"),
    )
    op.create_index("ix_user_stealth_states_user_id", "user_stealth_states", ["user_id"])
    op.create_index("ix_user_stealth_states_is_enabled", "user_stealth_states", ["is_enabled"])

    op.create_table(
        "profile_display_audits",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("actor_user_id", sa.Integer(), nullable=True),
        sa.Column("target_user_id", sa.Integer(), nullable=True),
        sa.Column("action", sa.String(length=100), nullable=False),
        sa.Column("previous_value", sa.Text(), nullable=True),
        sa.Column("new_value", sa.Text(), nullable=True),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["target_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_profile_display_audits_action", "profile_display_audits", ["action"])


def downgrade() -> None:
    op.drop_index("ix_profile_display_audits_action", table_name="profile_display_audits")
    op.drop_table("profile_display_audits")
    op.drop_index("ix_user_stealth_states_is_enabled", table_name="user_stealth_states")
    op.drop_index("ix_user_stealth_states_user_id", table_name="user_stealth_states")
    op.drop_table("user_stealth_states")
    op.drop_index("ix_store_asset_manifests_status", table_name="store_asset_manifests")
    op.drop_index("ix_store_asset_manifests_manifest_key", table_name="store_asset_manifests")
    op.drop_table("store_asset_manifests")
    op.drop_index("ix_user_store_inventory_granted_by_user_id", table_name="user_store_inventory")
    op.drop_column("user_store_inventory", "granted_by_user_id")
    op.drop_column("user_store_inventory", "ownership_type")
    for column_name in [
        "admin_notes",
        "metadata_json",
        "catalog_version",
        "cache_key",
        "asset_version",
        "official_only",
        "svip_required_level",
        "vip_required_level",
        "visibility",
        "video_url",
        "animation_url",
        "thumbnail_url",
        "cdn_asset_url",
        "duration_days",
        "ownership_type",
        "currency_type",
        "item_type",
    ]:
        op.drop_column("store_items", column_name)
    op.drop_index("ix_store_categories_is_active", table_name="store_categories")
    op.drop_index("ix_store_categories_category_key", table_name="store_categories")
    op.drop_table("store_categories")
    op.drop_index("ix_economy_rule_levels_level", table_name="economy_rule_levels")
    op.drop_index("ix_economy_rule_levels_rule_set_id", table_name="economy_rule_levels")
    op.drop_table("economy_rule_levels")
    op.drop_index("ix_economy_rule_sets_is_published", table_name="economy_rule_sets")
    op.drop_index("ix_economy_rule_sets_is_active", table_name="economy_rule_sets")
    op.drop_index("ix_economy_rule_sets_track_key", table_name="economy_rule_sets")
    op.drop_table("economy_rule_sets")
