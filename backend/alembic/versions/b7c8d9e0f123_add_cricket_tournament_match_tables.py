"""add cricket tournament match tables

Revision ID: b7c8d9e0f123
Revises: eeeb28fa72a4
Create Date: 2026-05-12 18:30:00.000000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "b7c8d9e0f123"
down_revision = "eeeb28fa72a4"
branch_labels = None
depends_on = None


cricket_tournament_status = postgresql.ENUM(
    "ACTIVE",
    "COMPLETED",
    "DELETED",
    name="crickettournamentstatus",
    create_type=False,
)

cricket_match_status = postgresql.ENUM(
    "SCHEDULED",
    "TOSS_PENDING",
    "LINEUP_PENDING",
    "LIVE",
    "INNINGS_BREAK",
    "COMPLETED",
    "DELETED",
    name="cricketmatchstatus",
    create_type=False,
)


def _table_exists(table_name: str) -> bool:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    return table_name in inspector.get_table_names()


def _index_exists(table_name: str, index_name: str) -> bool:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    return any(index["name"] == index_name for index in inspector.get_indexes(table_name))


def _create_index_if_missing(index_name: str, table_name: str, columns: list[str]) -> None:
    if _table_exists(table_name) and not _index_exists(table_name, index_name):
        op.create_index(index_name, table_name, columns, unique=False)


def _drop_index_if_exists(index_name: str, table_name: str) -> None:
    if _table_exists(table_name) and _index_exists(table_name, index_name):
        op.drop_index(index_name, table_name=table_name)


def upgrade() -> None:
    bind = op.get_bind()

    postgresql.ENUM(
        "ACTIVE",
        "COMPLETED",
        "DELETED",
        name="crickettournamentstatus",
    ).create(bind, checkfirst=True)

    postgresql.ENUM(
        "SCHEDULED",
        "TOSS_PENDING",
        "LINEUP_PENDING",
        "LIVE",
        "INNINGS_BREAK",
        "COMPLETED",
        "DELETED",
        name="cricketmatchstatus",
    ).create(bind, checkfirst=True)

    if not _table_exists("cricket_tournaments"):
        op.create_table(
            "cricket_tournaments",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("room_public_id", sa.String(length=32), nullable=False),
            sa.Column("created_by_user_id", sa.Integer(), nullable=False),
            sa.Column("name", sa.String(length=160), nullable=False),
            sa.Column("status", cricket_tournament_status, nullable=False),
            sa.Column("team_count", sa.Integer(), nullable=False),
            sa.Column("players_per_team", sa.Integer(), nullable=False),
            sa.Column("overs_per_innings", sa.Integer(), nullable=False),
            sa.Column("wickets_per_side", sa.Integer(), nullable=False),
            sa.Column("matches_per_team", sa.Integer(), nullable=False),
            sa.Column("matches_vs_each_team", sa.Integer(), nullable=False),
            sa.Column("allow_same_player_across_teams", sa.Boolean(), nullable=False),
            sa.Column("rules_json", sa.JSON(), nullable=False),
            sa.Column("teams_json", sa.JSON(), nullable=False),
            sa.Column("fixtures_json", sa.JSON(), nullable=False),
            sa.Column("points_table_json", sa.JSON(), nullable=False),
            sa.Column("deleted_reason", sa.Text(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
            sa.Column("deleted_at", sa.DateTime(), nullable=True),
            sa.ForeignKeyConstraint(["created_by_user_id"], ["users.id"]),
            sa.PrimaryKeyConstraint("id"),
        )

    _create_index_if_missing("ix_cricket_tournaments_id", "cricket_tournaments", ["id"])
    _create_index_if_missing("ix_cricket_tournaments_room_public_id", "cricket_tournaments", ["room_public_id"])
    _create_index_if_missing("ix_cricket_tournaments_created_by_user_id", "cricket_tournaments", ["created_by_user_id"])

    if not _table_exists("cricket_matches"):
        op.create_table(
            "cricket_matches",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("tournament_id", sa.Integer(), nullable=True),
            sa.Column("room_public_id", sa.String(length=32), nullable=False),
            sa.Column("created_by_user_id", sa.Integer(), nullable=False),
            sa.Column("status", cricket_match_status, nullable=False),
            sa.Column("match_type", sa.String(length=32), nullable=False),
            sa.Column("team_a_json", sa.JSON(), nullable=False),
            sa.Column("team_b_json", sa.JSON(), nullable=False),
            sa.Column("toss_json", sa.JSON(), nullable=False),
            sa.Column("lineup_json", sa.JSON(), nullable=False),
            sa.Column("score_json", sa.JSON(), nullable=False),
            sa.Column("ball_events_json", sa.JSON(), nullable=False),
            sa.Column("result_json", sa.JSON(), nullable=False),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(["created_by_user_id"], ["users.id"]),
            sa.ForeignKeyConstraint(["tournament_id"], ["cricket_tournaments.id"]),
            sa.PrimaryKeyConstraint("id"),
        )

    _create_index_if_missing("ix_cricket_matches_id", "cricket_matches", ["id"])
    _create_index_if_missing("ix_cricket_matches_tournament_id", "cricket_matches", ["tournament_id"])
    _create_index_if_missing("ix_cricket_matches_room_public_id", "cricket_matches", ["room_public_id"])
    _create_index_if_missing("ix_cricket_matches_created_by_user_id", "cricket_matches", ["created_by_user_id"])


def downgrade() -> None:
    _drop_index_if_exists("ix_cricket_matches_created_by_user_id", "cricket_matches")
    _drop_index_if_exists("ix_cricket_matches_room_public_id", "cricket_matches")
    _drop_index_if_exists("ix_cricket_matches_tournament_id", "cricket_matches")
    _drop_index_if_exists("ix_cricket_matches_id", "cricket_matches")
    if _table_exists("cricket_matches"):
        op.drop_table("cricket_matches")

    _drop_index_if_exists("ix_cricket_tournaments_created_by_user_id", "cricket_tournaments")
    _drop_index_if_exists("ix_cricket_tournaments_room_public_id", "cricket_tournaments")
    _drop_index_if_exists("ix_cricket_tournaments_id", "cricket_tournaments")
    if _table_exists("cricket_tournaments"):
        op.drop_table("cricket_tournaments")

    postgresql.ENUM(name="cricketmatchstatus").drop(op.get_bind(), checkfirst=True)
    postgresql.ENUM(name="crickettournamentstatus").drop(op.get_bind(), checkfirst=True)
