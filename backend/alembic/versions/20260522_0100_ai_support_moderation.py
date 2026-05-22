"""add ai support inbox helper and moderation foundation

Revision ID: 20260522_0100
Revises: 20260518_0110
Create Date: 2026-05-22 01:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "20260522_0100"
down_revision = "20260518_0110"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "support_tickets",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("public_id", sa.String(length=80), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("category", sa.String(length=60), nullable=False),
        sa.Column("subject", sa.String(length=160), nullable=False),
        sa.Column("status", sa.String(length=60), nullable=False),
        sa.Column("priority", sa.String(length=30), nullable=False),
        sa.Column("assigned_role", sa.String(length=60), nullable=True),
        sa.Column("assigned_user_id", sa.Integer(), nullable=True),
        sa.Column("ai_summary", sa.Text(), nullable=True),
        sa.Column("ai_summary_generated", sa.Boolean(), nullable=False),
        sa.Column("missing_fields_json", sa.JSON(), nullable=True),
        sa.Column("resolution_reason", sa.Text(), nullable=True),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("resolved_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["assigned_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("public_id"),
    )
    for column in [
        "id",
        "public_id",
        "user_id",
        "category",
        "status",
        "priority",
        "assigned_role",
        "assigned_user_id",
        "created_at",
        "updated_at",
        "resolved_at",
    ]:
        op.create_index(f"ix_support_tickets_{column}", "support_tickets", [column])

    op.create_table(
        "support_messages",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("public_id", sa.String(length=80), nullable=False),
        sa.Column("ticket_id", sa.Integer(), nullable=False),
        sa.Column("sender_user_id", sa.Integer(), nullable=True),
        sa.Column("sender_role", sa.String(length=40), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("is_ai_generated", sa.Boolean(), nullable=False),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["sender_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["ticket_id"], ["support_tickets.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("public_id"),
    )
    for column in ["id", "public_id", "ticket_id", "sender_user_id", "sender_role", "is_ai_generated", "created_at"]:
        op.create_index(f"ix_support_messages_{column}", "support_messages", [column])

    op.create_table(
        "support_attachments",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("ticket_id", sa.Integer(), nullable=False),
        sa.Column("message_id", sa.Integer(), nullable=True),
        sa.Column("uploaded_by_user_id", sa.Integer(), nullable=False),
        sa.Column("file_url", sa.String(length=700), nullable=False),
        sa.Column("content_type", sa.String(length=120), nullable=True),
        sa.Column("moderation_status", sa.String(length=40), nullable=False),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["message_id"], ["support_messages.id"]),
        sa.ForeignKeyConstraint(["ticket_id"], ["support_tickets.id"]),
        sa.ForeignKeyConstraint(["uploaded_by_user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    for column in ["id", "ticket_id", "message_id", "uploaded_by_user_id", "moderation_status", "created_at"]:
        op.create_index(f"ix_support_attachments_{column}", "support_attachments", [column])

    op.create_table(
        "help_articles",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("slug", sa.String(length=120), nullable=False),
        sa.Column("category", sa.String(length=60), nullable=False),
        sa.Column("title", sa.String(length=180), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("tags_json", sa.JSON(), nullable=True),
        sa.Column("is_published", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("slug"),
    )
    for column in ["id", "slug", "category", "is_published", "created_at"]:
        op.create_index(f"ix_help_articles_{column}", "help_articles", [column])

    op.create_table(
        "ai_helpdesk_logs",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=True),
        sa.Column("ticket_id", sa.Integer(), nullable=True),
        sa.Column("provider", sa.String(length=40), nullable=False),
        sa.Column("model", sa.String(length=120), nullable=True),
        sa.Column("intent", sa.String(length=80), nullable=False),
        sa.Column("category", sa.String(length=60), nullable=False),
        sa.Column("priority", sa.String(length=30), nullable=False),
        sa.Column("prompt_preview", sa.Text(), nullable=True),
        sa.Column("output_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["ticket_id"], ["support_tickets.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    for column in ["id", "user_id", "ticket_id", "provider", "intent", "category", "priority", "created_at"]:
        op.create_index(f"ix_ai_helpdesk_logs_{column}", "ai_helpdesk_logs", [column])

    op.create_table(
        "moderation_events",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("public_id", sa.String(length=80), nullable=False),
        sa.Column("actor_user_id", sa.Integer(), nullable=True),
        sa.Column("target_user_id", sa.Integer(), nullable=True),
        sa.Column("room_id", sa.String(length=80), nullable=True),
        sa.Column("content_type", sa.String(length=40), nullable=False),
        sa.Column("surface", sa.String(length=60), nullable=False),
        sa.Column("decision", sa.String(length=40), nullable=False),
        sa.Column("severity", sa.String(length=30), nullable=False),
        sa.Column("provider", sa.String(length=40), nullable=False),
        sa.Column("categories_json", sa.JSON(), nullable=True),
        sa.Column("snippet", sa.Text(), nullable=True),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["target_user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("public_id"),
    )
    for column in ["id", "public_id", "actor_user_id", "target_user_id", "room_id", "content_type", "surface", "decision", "severity", "provider", "created_at"]:
        op.create_index(f"ix_moderation_events_{column}", "moderation_events", [column])

    op.create_table(
        "moderation_cases",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("public_id", sa.String(length=80), nullable=False),
        sa.Column("opened_by_user_id", sa.Integer(), nullable=True),
        sa.Column("target_user_id", sa.Integer(), nullable=True),
        sa.Column("room_id", sa.String(length=80), nullable=True),
        sa.Column("status", sa.String(length=40), nullable=False),
        sa.Column("category", sa.String(length=60), nullable=False),
        sa.Column("priority", sa.String(length=30), nullable=False),
        sa.Column("ai_recommendation", sa.Text(), nullable=True),
        sa.Column("moderator_notes", sa.Text(), nullable=True),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("closed_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["opened_by_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["target_user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("public_id"),
    )
    for column in ["id", "public_id", "opened_by_user_id", "target_user_id", "room_id", "status", "category", "priority", "created_at", "updated_at", "closed_at"]:
        op.create_index(f"ix_moderation_cases_{column}", "moderation_cases", [column])

    op.create_table(
        "moderation_evidence",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("case_id", sa.Integer(), nullable=False),
        sa.Column("event_id", sa.Integer(), nullable=True),
        sa.Column("evidence_type", sa.String(length=40), nullable=False),
        sa.Column("content_url", sa.String(length=700), nullable=True),
        sa.Column("text_snapshot", sa.Text(), nullable=True),
        sa.Column("moderation_status", sa.String(length=40), nullable=False),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["case_id"], ["moderation_cases.id"]),
        sa.ForeignKeyConstraint(["event_id"], ["moderation_events.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    for column in ["id", "case_id", "event_id", "evidence_type", "moderation_status", "created_at"]:
        op.create_index(f"ix_moderation_evidence_{column}", "moderation_evidence", [column])

    op.create_table(
        "user_violation_scores",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("score", sa.Integer(), nullable=False),
        sa.Column("severity", sa.String(length=30), nullable=False),
        sa.Column("last_event_id", sa.Integer(), nullable=True),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["last_event_id"], ["moderation_events.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id"),
    )
    for column in ["id", "user_id", "score", "severity", "last_event_id", "updated_at"]:
        op.create_index(f"ix_user_violation_scores_{column}", "user_violation_scores", [column])

    op.create_table(
        "user_app_settings",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("settings_json", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id"),
    )
    for column in ["id", "user_id", "created_at", "updated_at"]:
        op.create_index(f"ix_user_app_settings_{column}", "user_app_settings", [column])


def downgrade() -> None:
    for table, columns in [
        ("user_app_settings", ["updated_at", "created_at", "user_id", "id"]),
        ("user_violation_scores", ["updated_at", "last_event_id", "severity", "score", "user_id", "id"]),
        ("moderation_evidence", ["created_at", "moderation_status", "evidence_type", "event_id", "case_id", "id"]),
        ("moderation_cases", ["closed_at", "updated_at", "created_at", "priority", "category", "status", "room_id", "target_user_id", "opened_by_user_id", "public_id", "id"]),
        ("moderation_events", ["created_at", "provider", "severity", "decision", "surface", "content_type", "room_id", "target_user_id", "actor_user_id", "public_id", "id"]),
        ("ai_helpdesk_logs", ["created_at", "priority", "category", "intent", "provider", "ticket_id", "user_id", "id"]),
        ("help_articles", ["created_at", "is_published", "category", "slug", "id"]),
        ("support_attachments", ["created_at", "moderation_status", "uploaded_by_user_id", "message_id", "ticket_id", "id"]),
        ("support_messages", ["created_at", "is_ai_generated", "sender_role", "sender_user_id", "ticket_id", "public_id", "id"]),
        ("support_tickets", ["resolved_at", "updated_at", "created_at", "assigned_user_id", "assigned_role", "priority", "status", "category", "user_id", "public_id", "id"]),
    ]:
        for column in columns:
            op.drop_index(f"ix_{table}_{column}", table_name=table)
        op.drop_table(table)
