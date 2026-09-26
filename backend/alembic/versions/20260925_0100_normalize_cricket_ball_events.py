"""Normalize Room Cricket ball events for serialized scoring.

Revision ID: 20260925_0100
Revises: 20260924_1200
"""
from __future__ import annotations

import json
from datetime import datetime

from alembic import op
import sqlalchemy as sa


revision = "20260925_0100"
down_revision = "20260924_1200"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "cricket_ball_events",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("match_id", sa.Integer(), nullable=False),
        sa.Column("sequence", sa.Integer(), nullable=False),
        sa.Column("event_json", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["match_id"],
            ["cricket_matches.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "match_id",
            "sequence",
            name="uq_cricket_ball_event_match_sequence",
        ),
    )
    op.create_index(
        "ix_cricket_ball_events_id",
        "cricket_ball_events",
        ["id"],
    )
    op.create_index(
        "ix_cricket_ball_events_match_id",
        "cricket_ball_events",
        ["match_id"],
    )

    bind = op.get_bind()
    matches = bind.execute(
        sa.text("SELECT id, ball_events_json FROM cricket_matches")
    ).mappings()
    event_table = sa.table(
        "cricket_ball_events",
        sa.column("match_id", sa.Integer()),
        sa.column("sequence", sa.Integer()),
        sa.column("event_json", sa.JSON()),
        sa.column("created_at", sa.DateTime()),
    )
    for row in matches:
        raw_events = row["ball_events_json"] or []
        if isinstance(raw_events, str):
            try:
                raw_events = json.loads(raw_events)
            except json.JSONDecodeError:
                raw_events = []
        if not isinstance(raw_events, list):
            continue
        used_sequences: set[int] = set()
        next_sequence = 1
        for index, raw_event in enumerate(raw_events, start=1):
            event = dict(raw_event) if isinstance(raw_event, dict) else {"value": raw_event}
            requested_sequence = int(event.get("sequence") or index)
            sequence = requested_sequence
            if sequence <= 0 or sequence in used_sequences:
                sequence = next_sequence
                while sequence in used_sequences:
                    sequence += 1
            used_sequences.add(sequence)
            next_sequence = max(next_sequence, sequence + 1)
            event["sequence"] = sequence
            created_at = event.get("created_at")
            parsed_created_at = datetime.utcnow()
            if isinstance(created_at, str):
                try:
                    parsed_created_at = datetime.fromisoformat(
                        created_at.replace("Z", "+00:00")
                    ).replace(tzinfo=None)
                except ValueError:
                    pass
            bind.execute(
                event_table.insert().values(
                    match_id=int(row["id"]),
                    sequence=sequence,
                    event_json=event,
                    created_at=parsed_created_at,
                )
            )


def downgrade() -> None:
    op.drop_index(
        "ix_cricket_ball_events_match_id",
        table_name="cricket_ball_events",
    )
    op.drop_index(
        "ix_cricket_ball_events_id",
        table_name="cricket_ball_events",
    )
    op.drop_table("cricket_ball_events")
