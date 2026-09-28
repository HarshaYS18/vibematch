"""Notification Service authority, preferences and provider delivery state.
Revision ID: 20260924_0900
Revises: 20260924_0800
"""
from alembic import op
import sqlalchemy as sa
revision="20260924_0900"; down_revision="20260924_0800"; branch_labels=None; depends_on=None

def upgrade():
    op.add_column("user_notifications",sa.Column("source_event_id",sa.String(length=36),nullable=True))
    op.add_column("user_notifications",sa.Column("dedupe_key",sa.String(length=180),nullable=True))
    op.add_column("user_notifications",sa.Column("collapse_key",sa.String(length=120),nullable=True))
    op.create_index("ix_user_notifications_source_event_id","user_notifications",["source_event_id"],unique=False)
    op.create_index("uq_user_notifications_recipient_dedupe","user_notifications",["recipient_user_id","dedupe_key"],unique=True)
    op.create_table("notification_preferences",
        sa.Column("id",sa.Integer(),nullable=False),sa.Column("user_id",sa.Integer(),nullable=False),sa.Column("push_enabled",sa.Boolean(),nullable=False,server_default=sa.true()),
        sa.Column("quiet_start_minute",sa.Integer(),nullable=True),sa.Column("quiet_end_minute",sa.Integer(),nullable=True),sa.Column("timezone",sa.String(length=64),nullable=False,server_default="UTC"),
        sa.Column("max_push_per_hour",sa.Integer(),nullable=False,server_default="20"),sa.Column("notification_types_json",sa.JSON(),nullable=True),sa.Column("created_at",sa.DateTime(),nullable=False),sa.Column("updated_at",sa.DateTime(),nullable=False),
        sa.ForeignKeyConstraint(["user_id"],["users.id"],ondelete="CASCADE"),sa.PrimaryKeyConstraint("id"),sa.UniqueConstraint("user_id"))
    op.create_index("ix_notification_preferences_user_id","notification_preferences",["user_id"],unique=True)
    op.create_table("notification_templates",
        sa.Column("id",sa.Integer(),nullable=False),sa.Column("template_key",sa.String(length=120),nullable=False),sa.Column("version",sa.Integer(),nullable=False,server_default="1"),sa.Column("notification_type",sa.String(length=60),nullable=False),
        sa.Column("title_template",sa.String(length=160),nullable=False),sa.Column("body_template",sa.Text(),nullable=False),sa.Column("enabled",sa.Boolean(),nullable=False,server_default=sa.true()),sa.Column("created_at",sa.DateTime(),nullable=False),sa.Column("updated_at",sa.DateTime(),nullable=False),sa.PrimaryKeyConstraint("id"))
    op.create_index("ix_notification_templates_template_key","notification_templates",["template_key"],unique=False); op.create_index("ix_notification_templates_enabled","notification_templates",["enabled"],unique=False); op.create_index("uq_notification_templates_key_version","notification_templates",["template_key","version"],unique=True)
    op.create_table("notification_deliveries",
        sa.Column("id",sa.Integer(),nullable=False),sa.Column("notification_id",sa.Integer(),nullable=False),sa.Column("device_token_id",sa.Integer(),nullable=False),sa.Column("status",sa.String(length=30),nullable=False,server_default="PENDING"),
        sa.Column("attempt_count",sa.Integer(),nullable=False,server_default="0"),sa.Column("next_attempt_at",sa.DateTime(),nullable=False),sa.Column("collapse_key",sa.String(length=120),nullable=True),sa.Column("provider_message_id",sa.String(length=300),nullable=True),
        sa.Column("last_error_code",sa.String(length=120),nullable=True),sa.Column("last_error_detail",sa.String(length=500),nullable=True),sa.Column("lock_token",sa.String(length=36),nullable=True),sa.Column("locked_until",sa.DateTime(),nullable=True),sa.Column("sent_at",sa.DateTime(),nullable=True),
        sa.Column("created_at",sa.DateTime(),nullable=False),sa.Column("updated_at",sa.DateTime(),nullable=False),sa.ForeignKeyConstraint(["notification_id"],["user_notifications.id"],ondelete="CASCADE"),sa.ForeignKeyConstraint(["device_token_id"],["push_device_tokens.id"],ondelete="CASCADE"),sa.PrimaryKeyConstraint("id"))
    for column in ("notification_id","device_token_id","status","next_attempt_at","lock_token","locked_until"): op.create_index(f"ix_notification_deliveries_{column}","notification_deliveries",[column],unique=False)
    op.create_index("uq_notification_delivery_target","notification_deliveries",["notification_id","device_token_id"],unique=True)

def downgrade():
    op.drop_table("notification_deliveries"); op.drop_table("notification_templates"); op.drop_table("notification_preferences")
    op.drop_index("uq_user_notifications_recipient_dedupe",table_name="user_notifications"); op.drop_index("ix_user_notifications_source_event_id",table_name="user_notifications")
    op.drop_column("user_notifications","collapse_key"); op.drop_column("user_notifications","dedupe_key"); op.drop_column("user_notifications","source_event_id")
