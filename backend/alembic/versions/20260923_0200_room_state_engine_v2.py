"""room state engine v2 current-state foundation

Revision ID: 20260923_0200
Revises: 20260923_0100
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta

from alembic import op
import sqlalchemy as sa


revision = "20260923_0200"
down_revision = "20260923_0100"
branch_labels = None
depends_on = None


def _payload(value):
    if isinstance(value, dict):
        return value
    if isinstance(value, str):
        try:
            decoded = json.loads(value)
            return decoded if isinstance(decoded, dict) else {}
        except json.JSONDecodeError:
            return {}
    return {}


def upgrade() -> None:
    op.add_column(
        "rooms",
        sa.Column("realtime_version", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column(
        "rooms",
        sa.Column("realtime_event_sequence", sa.Integer(), nullable=False, server_default="0"),
    )

    op.add_column("room_realtime_events", sa.Column("event_id", sa.String(length=64), nullable=True))
    op.add_column("room_realtime_events", sa.Column("room_version", sa.Integer(), nullable=True))
    op.execute(
        """
        UPDATE room_realtime_events
        SET event_id = 'legacy-' || CAST(id AS VARCHAR),
            room_version = sequence
        WHERE event_id IS NULL OR room_version IS NULL
        """
    )
    op.alter_column("room_realtime_events", "event_id", nullable=False)
    op.alter_column("room_realtime_events", "room_version", nullable=False)
    op.create_index(
        "ux_room_realtime_events_event_id",
        "room_realtime_events",
        ["event_id"],
        unique=True,
    )
    op.create_index(
        "ix_room_realtime_events_room_version",
        "room_realtime_events",
        ["room_version"],
        unique=False,
    )
    op.create_index(
        "ix_room_realtime_events_room_sequence",
        "room_realtime_events",
        ["room_id", "sequence"],
        unique=False,
    )

    op.execute(
        """
        UPDATE rooms
        SET realtime_event_sequence = COALESCE(
                (SELECT MAX(e.sequence)
                 FROM room_realtime_events e
                 WHERE e.room_id = rooms.id),
                0
            ),
            realtime_version = COALESCE(
                (SELECT MAX(e.room_version)
                 FROM room_realtime_events e
                 WHERE e.room_id = rooms.id),
                0
            )
        """
    )

    op.create_table(
        "room_member_requests",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("room_id", sa.Integer(), nullable=False),
        sa.Column("requester_user_id", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False, server_default="pending"),
        sa.Column("source_event_id", sa.Integer(), nullable=True),
        sa.Column("requested_at", sa.DateTime(), nullable=False),
        sa.Column("decided_at", sa.DateTime(), nullable=True),
        sa.Column("decided_by_user_id", sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(["room_id"], ["rooms.id"]),
        sa.ForeignKeyConstraint(["requester_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["source_event_id"], ["room_realtime_events.id"]),
        sa.ForeignKeyConstraint(["decided_by_user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    for name, columns in (
        ("ix_room_member_requests_room_id", ["room_id"]),
        ("ix_room_member_requests_requester_user_id", ["requester_user_id"]),
        ("ix_room_member_requests_status", ["status"]),
        ("ix_room_member_requests_source_event_id", ["source_event_id"]),
        ("ix_room_member_requests_requested_at", ["requested_at"]),
    ):
        op.create_index(name, "room_member_requests", columns, unique=False)

    op.create_table(
        "room_seat_applications",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("application_id", sa.String(length=120), nullable=False),
        sa.Column("room_id", sa.Integer(), nullable=False),
        sa.Column("applicant_user_id", sa.Integer(), nullable=False),
        sa.Column("seat_index", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False, server_default="pending"),
        sa.Column("source_event_id", sa.Integer(), nullable=True),
        sa.Column("requested_at", sa.DateTime(), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("decided_at", sa.DateTime(), nullable=True),
        sa.Column("decided_by_user_id", sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(["room_id"], ["rooms.id"]),
        sa.ForeignKeyConstraint(["applicant_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["source_event_id"], ["room_realtime_events.id"]),
        sa.ForeignKeyConstraint(["decided_by_user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ux_room_seat_applications_application_id",
        "room_seat_applications",
        ["application_id"],
        unique=True,
    )
    for name, columns in (
        ("ix_room_seat_applications_room_id", ["room_id"]),
        ("ix_room_seat_applications_applicant_user_id", ["applicant_user_id"]),
        ("ix_room_seat_applications_seat_index", ["seat_index"]),
        ("ix_room_seat_applications_status", ["status"]),
        ("ix_room_seat_applications_source_event_id", ["source_event_id"]),
        ("ix_room_seat_applications_requested_at", ["requested_at"]),
        ("ix_room_seat_applications_expires_at", ["expires_at"]),
    ):
        op.create_index(name, "room_seat_applications", columns, unique=False)

    bind = op.get_bind()
    relevant = bind.execute(
        sa.text(
            """
            SELECT id, room_id, event_type, actor_user_id, target_user_id,
                   payload, created_at
            FROM room_realtime_events
            WHERE event_type IN (
                'room.member_request.pending',
                'room.member_request.approved',
                'room.member_request.rejected',
                'room.member.removed',
                'seat.application.requested',
                'seat.application.rejected',
                'seat.taken',
                'seat.left',
                'room.user.kicked',
                'room.left'
            )
            ORDER BY id ASC
            """
        )
    ).mappings()

    member_pending = {}
    seat_pending = {}
    for row in relevant:
        event_type = row["event_type"]
        room_id = int(row["room_id"])
        actor = row["actor_user_id"]
        target = row["target_user_id"]
        payload = _payload(row["payload"])

        if event_type == "room.member_request.pending" and actor is not None:
            member_pending[(room_id, int(actor))] = dict(row)
            continue
        if event_type in {
            "room.member_request.approved",
            "room.member_request.rejected",
            "room.member.removed",
        } and target is not None:
            member_pending.pop((room_id, int(target)), None)
            continue

        if event_type == "seat.application.requested" and actor is not None:
            try:
                seat_index = int(payload.get("seat_index"))
            except (TypeError, ValueError):
                continue
            seat_pending[(room_id, int(actor), seat_index)] = dict(row)
            continue

        affected = target if target is not None else actor
        if affected is None:
            continue
        affected = int(affected)
        if event_type == "seat.application.rejected":
            try:
                seat_index = int(payload.get("seat_index"))
            except (TypeError, ValueError):
                seat_index = None
            for key in list(seat_pending):
                if key[0] == room_id and key[1] == affected and (
                    seat_index is None or key[2] == seat_index
                ):
                    seat_pending.pop(key, None)
        elif event_type in {"seat.taken", "seat.left", "room.user.kicked", "room.left"}:
            for key in list(seat_pending):
                if key[0] == room_id and key[1] == affected:
                    seat_pending.pop(key, None)

    member_table = sa.table(
        "room_member_requests",
        sa.column("room_id", sa.Integer()),
        sa.column("requester_user_id", sa.Integer()),
        sa.column("status", sa.String()),
        sa.column("source_event_id", sa.Integer()),
        sa.column("requested_at", sa.DateTime()),
    )
    member_rows = []
    for (room_id, user_id), row in member_pending.items():
        already_member = bind.execute(
            sa.text(
                """
                SELECT 1 FROM room_participants
                WHERE room_id = :room_id
                  AND user_id = :user_id
                  AND is_member = true
                LIMIT 1
                """
            ),
            {"room_id": room_id, "user_id": user_id},
        ).first()
        if already_member:
            continue
        member_rows.append(
            {
                "room_id": room_id,
                "requester_user_id": user_id,
                "status": "pending",
                "source_event_id": int(row["id"]),
                "requested_at": row["created_at"] or datetime.utcnow(),
            }
        )
    if member_rows:
        op.bulk_insert(member_table, member_rows)

    seat_table = sa.table(
        "room_seat_applications",
        sa.column("application_id", sa.String()),
        sa.column("room_id", sa.Integer()),
        sa.column("applicant_user_id", sa.Integer()),
        sa.column("seat_index", sa.Integer()),
        sa.column("status", sa.String()),
        sa.column("source_event_id", sa.Integer()),
        sa.column("requested_at", sa.DateTime()),
        sa.column("expires_at", sa.DateTime()),
    )
    seat_rows = []
    now = datetime.utcnow()
    for (room_id, user_id, seat_index), row in seat_pending.items():
        payload = _payload(row["payload"])
        requested_at = row["created_at"] or now
        raw_expires = payload.get("expires_at")
        try:
            expires_at = datetime.fromisoformat(str(raw_expires)) if raw_expires else None
        except ValueError:
            expires_at = None
        expires_at = expires_at or (requested_at + timedelta(seconds=20))
        if expires_at <= now:
            continue
        seat_rows.append(
            {
                "application_id": str(payload.get("id") or f"legacy-seat-application-{row['id']}"),
                "room_id": room_id,
                "applicant_user_id": user_id,
                "seat_index": seat_index,
                "status": "pending",
                "source_event_id": int(row["id"]),
                "requested_at": requested_at,
                "expires_at": expires_at,
            }
        )
    if seat_rows:
        op.bulk_insert(seat_table, seat_rows)


def downgrade() -> None:
    raise RuntimeError(
        "Forward-only migration: Room State Engine v2 counters and current-state tables are additive"
    )
