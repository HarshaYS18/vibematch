from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, Column, DateTime
from sqlalchemy import Enum as SqlEnum
from sqlalchemy import ForeignKey, Integer, JSON, String, Text, UniqueConstraint

from app.database import Base


class CricketTournamentStatus(str, Enum):
    ACTIVE = "active"
    COMPLETED = "completed"
    DELETED = "deleted"


class CricketMatchStatus(str, Enum):
    SCHEDULED = "scheduled"
    TOSS_PENDING = "toss_pending"
    LINEUP_PENDING = "lineup_pending"
    LIVE = "live"
    INNINGS_BREAK = "innings_break"
    COMPLETED = "completed"
    DELETED = "deleted"


class CricketTournament(Base):
    __tablename__ = "cricket_tournaments"

    id = Column(Integer, primary_key=True, index=True)
    room_public_id = Column(String(32), index=True, nullable=False)
    created_by_user_id = Column(Integer, ForeignKey("users.id"), index=True, nullable=False)
    name = Column(String(160), nullable=False)
    status = Column(
        SqlEnum(CricketTournamentStatus),
        default=CricketTournamentStatus.ACTIVE,
        nullable=False,
    )
    team_count = Column(Integer, nullable=False)
    players_per_team = Column(Integer, nullable=False)
    overs_per_innings = Column(Integer, nullable=False)
    wickets_per_side = Column(Integer, nullable=False)
    matches_per_team = Column(Integer, nullable=False)
    matches_vs_each_team = Column(Integer, nullable=False)
    allow_same_player_across_teams = Column(Boolean, default=False, nullable=False)
    rules_json = Column(JSON, default=dict, nullable=False)
    teams_json = Column(JSON, default=list, nullable=False)
    fixtures_json = Column(JSON, default=list, nullable=False)
    points_table_json = Column(JSON, default=list, nullable=False)
    deleted_reason = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    deleted_at = Column(DateTime, nullable=True)


class CricketMatch(Base):
    __tablename__ = "cricket_matches"

    id = Column(Integer, primary_key=True, index=True)
    tournament_id = Column(Integer, ForeignKey("cricket_tournaments.id"), index=True, nullable=True)
    room_public_id = Column(String(32), index=True, nullable=False)
    created_by_user_id = Column(Integer, ForeignKey("users.id"), index=True, nullable=False)
    status = Column(
        SqlEnum(CricketMatchStatus),
        default=CricketMatchStatus.SCHEDULED,
        nullable=False,
    )
    match_type = Column(String(32), default="tournament", nullable=False)
    team_a_json = Column(JSON, default=dict, nullable=False)
    team_b_json = Column(JSON, default=dict, nullable=False)
    toss_json = Column(JSON, default=dict, nullable=False)
    lineup_json = Column(JSON, default=dict, nullable=False)
    score_json = Column(JSON, default=dict, nullable=False)
    ball_events_json = Column(JSON, default=list, nullable=False)
    result_json = Column(JSON, default=dict, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)



class CricketBallEvent(Base):
    __tablename__ = "cricket_ball_events"
    __table_args__ = (
        UniqueConstraint(
            "match_id",
            "sequence",
            name="uq_cricket_ball_event_match_sequence",
        ),
        UniqueConstraint(
            "match_id",
            "source_event_id",
            name="uq_cricket_ball_event_match_source",
        ),
    )

    id = Column(Integer, primary_key=True, index=True)
    match_id = Column(
        Integer,
        ForeignKey("cricket_matches.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    sequence = Column(Integer, nullable=False)
    source_event_id = Column(String(80), nullable=True)
    event_json = Column(JSON, default=dict, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
