"""add persistent room realtime state

Revision ID: 20260517_0100
Revises: d1e2f3a4b567
Create Date: 2026-05-17 01:00:00.000000
"""

from alembic import op
from legacy_snapshot import is_fresh_bootstrap, create_table, add_column, create_index
import sqlalchemy as sa


revision = "20260517_0100"
down_revision = "d1e2f3a4b567"
branch_labels = None
depends_on = None


def upgrade() -> None:
    if is_fresh_bootstrap(op.get_bind()):
        return
    create_table(
        "room_seat_states",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("room_id", sa.Integer(), nullable=False),
        sa.Column("seat_index", sa.Integer(), nullable=False),
        sa.Column("occupant_user_id", sa.Integer(), nullable=True),
        sa.Column("is_locked", sa.Boolean(), nullable=False),
        sa.Column("mic_enabled", sa.Boolean(), nullable=False),
        sa.Column("admin_muted", sa.Boolean(), nullable=False),
        sa.Column("locked_by_user_id", sa.Integer(), nullable=True),
        sa.Column("admin_muted_by_user_id", sa.Integer(), nullable=True),
        sa.Column("updated_by_user_id", sa.Integer(), nullable=True),
        sa.Column("occupied_at", sa.DateTime(), nullable=True),
        sa.Column("left_at", sa.DateTime(), nullable=True),
        sa.Column("locked_at", sa.DateTime(), nullable=True),
        sa.Column("admin_muted_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["occupant_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["room_id"], ["rooms.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("room_id", "seat_index", name="uq_room_seat_state_room_seat"),
    )
    create_index(op.f("ix_room_seat_states_id"), "room_seat_states", ["id"], unique=False)
    create_index(op.f("ix_room_seat_states_room_id"), "room_seat_states", ["room_id"], unique=False)
    create_index(op.f("ix_room_seat_states_seat_index"), "room_seat_states", ["seat_index"], unique=False)
    create_index(op.f("ix_room_seat_states_occupant_user_id"), "room_seat_states", ["occupant_user_id"], unique=False)
    create_index(op.f("ix_room_seat_states_is_locked"), "room_seat_states", ["is_locked"], unique=False)

    create_table(
        "room_realtime_events",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("room_id", sa.Integer(), nullable=False),
        sa.Column("room_public_id", sa.String(length=32), nullable=False),
        sa.Column("event_type", sa.String(length=80), nullable=False),
        sa.Column("actor_user_id", sa.Integer(), nullable=True),
        sa.Column("target_user_id", sa.Integer(), nullable=True),
        sa.Column("payload", sa.JSON(), nullable=True),
        sa.Column("privacy_scope", sa.String(length=40), nullable=False),
        sa.Column("sequence", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["room_id"], ["rooms.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    create_index(op.f("ix_room_realtime_events_id"), "room_realtime_events", ["id"], unique=False)
    create_index(op.f("ix_room_realtime_events_room_id"), "room_realtime_events", ["room_id"], unique=False)
    create_index(op.f("ix_room_realtime_events_room_public_id"), "room_realtime_events", ["room_public_id"], unique=False)
    create_index(op.f("ix_room_realtime_events_event_type"), "room_realtime_events", ["event_type"], unique=False)
    create_index(op.f("ix_room_realtime_events_actor_user_id"), "room_realtime_events", ["actor_user_id"], unique=False)
    create_index(op.f("ix_room_realtime_events_target_user_id"), "room_realtime_events", ["target_user_id"], unique=False)
    create_index(op.f("ix_room_realtime_events_sequence"), "room_realtime_events", ["sequence"], unique=False)
    create_index(op.f("ix_room_realtime_events_created_at"), "room_realtime_events", ["created_at"], unique=False)

    create_table(
        "room_chat_messages",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("room_id", sa.Integer(), nullable=False),
        sa.Column("room_public_id", sa.String(length=32), nullable=False),
        sa.Column("sender_user_id", sa.Integer(), nullable=True),
        sa.Column("message_type", sa.String(length=40), nullable=False),
        sa.Column("text", sa.Text(), nullable=True),
        sa.Column("media_url", sa.String(length=500), nullable=True),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("is_deleted", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["room_id"], ["rooms.id"]),
        sa.ForeignKeyConstraint(["sender_user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    create_index(op.f("ix_room_chat_messages_id"), "room_chat_messages", ["id"], unique=False)
    create_index(op.f("ix_room_chat_messages_room_id"), "room_chat_messages", ["room_id"], unique=False)
    create_index(op.f("ix_room_chat_messages_room_public_id"), "room_chat_messages", ["room_public_id"], unique=False)
    create_index(op.f("ix_room_chat_messages_sender_user_id"), "room_chat_messages", ["sender_user_id"], unique=False)
    create_index(op.f("ix_room_chat_messages_message_type"), "room_chat_messages", ["message_type"], unique=False)
    create_index(op.f("ix_room_chat_messages_is_deleted"), "room_chat_messages", ["is_deleted"], unique=False)
    create_index(op.f("ix_room_chat_messages_created_at"), "room_chat_messages", ["created_at"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_room_chat_messages_created_at"), table_name="room_chat_messages")
    op.drop_index(op.f("ix_room_chat_messages_is_deleted"), table_name="room_chat_messages")
    op.drop_index(op.f("ix_room_chat_messages_message_type"), table_name="room_chat_messages")
    op.drop_index(op.f("ix_room_chat_messages_sender_user_id"), table_name="room_chat_messages")
    op.drop_index(op.f("ix_room_chat_messages_room_public_id"), table_name="room_chat_messages")
    op.drop_index(op.f("ix_room_chat_messages_room_id"), table_name="room_chat_messages")
    op.drop_index(op.f("ix_room_chat_messages_id"), table_name="room_chat_messages")
    op.drop_table("room_chat_messages")

    op.drop_index(op.f("ix_room_realtime_events_created_at"), table_name="room_realtime_events")
    op.drop_index(op.f("ix_room_realtime_events_sequence"), table_name="room_realtime_events")
    op.drop_index(op.f("ix_room_realtime_events_target_user_id"), table_name="room_realtime_events")
    op.drop_index(op.f("ix_room_realtime_events_actor_user_id"), table_name="room_realtime_events")
    op.drop_index(op.f("ix_room_realtime_events_event_type"), table_name="room_realtime_events")
    op.drop_index(op.f("ix_room_realtime_events_room_public_id"), table_name="room_realtime_events")
    op.drop_index(op.f("ix_room_realtime_events_room_id"), table_name="room_realtime_events")
    op.drop_index(op.f("ix_room_realtime_events_id"), table_name="room_realtime_events")
    op.drop_table("room_realtime_events")

    op.drop_index(op.f("ix_room_seat_states_is_locked"), table_name="room_seat_states")
    op.drop_index(op.f("ix_room_seat_states_occupant_user_id"), table_name="room_seat_states")
    op.drop_index(op.f("ix_room_seat_states_seat_index"), table_name="room_seat_states")
    op.drop_index(op.f("ix_room_seat_states_room_id"), table_name="room_seat_states")
    op.drop_index(op.f("ix_room_seat_states_id"), table_name="room_seat_states")
    op.drop_table("room_seat_states")
