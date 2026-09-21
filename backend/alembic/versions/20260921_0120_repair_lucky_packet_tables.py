"""repair Lucky Packet tables omitted by the frozen bootstrap snapshot

Revision ID: 20260921_0120
Revises: 20260921_0110
Create Date: 2026-09-21
"""

from alembic import op
import sqlalchemy as sa

from legacy_snapshot import create_index, create_table


revision = "20260921_0120"
down_revision = "20260921_0110"
branch_labels = None
depends_on = None


def upgrade() -> None:
    create_table(
        "lucky_packets",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("public_id", sa.String(length=80), nullable=False),
        sa.Column("room_id", sa.Integer(), nullable=False),
        sa.Column("sender_user_id", sa.Integer(), nullable=False),
        sa.Column("coin_amount", sa.BigInteger(), nullable=False),
        sa.Column("winner_count", sa.Integer(), nullable=False),
        sa.Column("message", sa.String(length=120), nullable=False),
        sa.Column("status", sa.String(length=30), nullable=False),
        sa.Column("claimed_count", sa.Integer(), nullable=False),
        sa.Column("claimed_coin_amount", sa.BigInteger(), nullable=False),
        sa.Column("refunded_coin_amount", sa.BigInteger(), nullable=False),
        sa.Column("allocation_json", sa.Text(), nullable=False),
        sa.Column("opens_at", sa.DateTime(), nullable=False),
        sa.Column("closes_at", sa.DateTime(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("closed_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["room_id"], ["rooms.id"]),
        sa.ForeignKeyConstraint(["sender_user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("public_id"),
    )
    create_index("ix_lucky_packets_public_id", "lucky_packets", ["public_id"], unique=True)
    create_index("ix_lucky_packets_room_id", "lucky_packets", ["room_id"], unique=False)
    create_index("ix_lucky_packets_sender_user_id", "lucky_packets", ["sender_user_id"], unique=False)
    create_index("ix_lucky_packets_status", "lucky_packets", ["status"], unique=False)
    create_index("ix_lucky_packets_opens_at", "lucky_packets", ["opens_at"], unique=False)
    create_index("ix_lucky_packets_closes_at", "lucky_packets", ["closes_at"], unique=False)
    create_index("ix_lucky_packets_created_at", "lucky_packets", ["created_at"], unique=False)

    create_table(
        "lucky_packet_claims",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("packet_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("reward_coin_amount", sa.BigInteger(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["packet_id"], ["lucky_packets.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("packet_id", "user_id", name="uq_lucky_packet_claim_user"),
    )
    create_index("ix_lucky_packet_claims_packet_id", "lucky_packet_claims", ["packet_id"], unique=False)
    create_index("ix_lucky_packet_claims_user_id", "lucky_packet_claims", ["user_id"], unique=False)
    create_index("ix_lucky_packet_claims_created_at", "lucky_packet_claims", ["created_at"], unique=False)


def downgrade() -> None:
    raise RuntimeError(
        "20260921_0120 is a forward-only repair migration; "
        "restore from backup rather than dropping Lucky Packet data."
    )
