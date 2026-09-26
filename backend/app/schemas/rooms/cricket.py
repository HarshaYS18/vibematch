from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field

from app.models.cricket import CricketMatchStatus, CricketTournamentStatus


class CricketTournamentCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    team_count: int = Field(ge=2, le=64)
    players_per_team: int = Field(ge=2, le=32)
    overs_per_innings: int = Field(ge=1, le=100)
    wickets_per_side: int = Field(ge=1, le=20)
    matches_per_team: int = Field(ge=1, le=100)
    matches_vs_each_team: int = Field(ge=1, le=20)
    allow_same_player_across_teams: bool = False
    rules: dict[str, Any] = Field(default_factory=dict)
    teams: list[dict[str, Any]] = Field(default_factory=list)
    fixtures: list[dict[str, Any]] = Field(default_factory=list)


class CricketTournamentUpdateRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=160)
    rules: dict[str, Any] | None = None
    teams: list[dict[str, Any]] | None = None
    fixtures: list[dict[str, Any]] | None = None
    points_table: list[dict[str, Any]] | None = None


class CricketTournamentResponse(BaseModel):
    id: int
    room_public_id: str
    created_by_user_id: int
    name: str
    status: CricketTournamentStatus
    team_count: int
    players_per_team: int
    overs_per_innings: int
    wickets_per_side: int
    matches_per_team: int
    matches_vs_each_team: int
    allow_same_player_across_teams: bool
    rules: dict[str, Any]
    teams: list[dict[str, Any]]
    fixtures: list[dict[str, Any]]
    points_table: list[dict[str, Any]]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class CricketTournamentDeleteResponse(BaseModel):
    id: int
    room_public_id: str
    status: CricketTournamentStatus
    deleted_reason: str | None = None
    deleted_at: datetime | None = None


class CricketMatchCreateRequest(BaseModel):
    tournament_id: int | None = None
    match_type: str = Field(default="tournament", max_length=32)
    team_a: dict[str, Any] = Field(default_factory=dict)
    team_b: dict[str, Any] = Field(default_factory=dict)


class CricketMatchTossRequest(BaseModel):
    toss_winner_team_id: str
    decision: str = Field(pattern="^(bat|ball|bowl)$")


class CricketMatchLineupRequest(BaseModel):
    batting_team_id: str
    bowling_team_id: str
    striker_player_id: str
    non_striker_player_id: str
    bowler_player_id: str


class CricketBallEventRequest(BaseModel):
    event_id: str | None = Field(default=None, min_length=8, max_length=80)
    sequence: int | None = None
    innings: int = Field(ge=1, le=4)
    over: int = Field(ge=0)
    ball: int = Field(ge=0, le=12)
    striker_player_id: str
    non_striker_player_id: str
    bowler_player_id: str
    runs_bat: int = Field(ge=0, le=12)
    extras_runs: int = Field(default=0, ge=0, le=12)
    extra_type: str | None = None
    is_legal_ball: bool = True
    wicket_type: str | None = None
    dismissed_player_id: str | None = None
    commentary: str = ""


class CricketMatchScorePatchRequest(BaseModel):
    score: dict[str, Any] = Field(default_factory=dict)
    result: dict[str, Any] | None = None
    points_table: list[dict[str, Any]] | None = None


class CricketMatchResponse(BaseModel):
    id: int
    tournament_id: int | None
    room_public_id: str
    created_by_user_id: int
    status: CricketMatchStatus
    match_type: str
    team_a: dict[str, Any]
    team_b: dict[str, Any]
    toss: dict[str, Any]
    lineup: dict[str, Any]
    score: dict[str, Any]
    ball_events: list[dict[str, Any]]
    result: dict[str, Any]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
