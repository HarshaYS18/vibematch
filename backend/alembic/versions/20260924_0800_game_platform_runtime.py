"""Game Platform sessions and idempotent game bets.

Revision ID: 20260924_0800
Revises: 20260924_0700
"""
from alembic import op
import sqlalchemy as sa
revision="20260924_0800"
down_revision="20260924_0700"
branch_labels=None
depends_on=None

def upgrade() -> None:
    op.create_table("game_sessions",
        sa.Column("id",sa.Integer(),nullable=False),
        sa.Column("session_id",sa.String(length=36),nullable=False),
        sa.Column("request_id",sa.String(length=160),nullable=False),
        sa.Column("user_id",sa.Integer(),nullable=False),
        sa.Column("game_key",sa.String(length=80),nullable=False),
        sa.Column("room_id",sa.Integer(),nullable=True),
        sa.Column("bridge_version",sa.Integer(),nullable=False,server_default="1"),
        sa.Column("status",sa.String(length=30),nullable=False,server_default="ACTIVE"),
        sa.Column("metadata_json",sa.Text(),nullable=True),
        sa.Column("opened_at",sa.DateTime(),nullable=False),
        sa.Column("closed_at",sa.DateTime(),nullable=True),
        sa.ForeignKeyConstraint(["user_id"],["users.id"],ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["room_id"],["rooms.id"],ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),sa.UniqueConstraint("session_id"),sa.UniqueConstraint("request_id"))
    for col in ("session_id","request_id","user_id","game_key","room_id","status","opened_at"):
        op.create_index(f"ix_game_sessions_{col}","game_sessions",[col],unique=col in {"session_id","request_id"})
    op.add_column("game_bets",sa.Column("request_id",sa.String(length=160),nullable=True))
    op.create_index("ix_game_bets_request_id","game_bets",["request_id"],unique=True)

def downgrade() -> None:
    op.drop_index("ix_game_bets_request_id",table_name="game_bets"); op.drop_column("game_bets","request_id"); op.drop_table("game_sessions")
