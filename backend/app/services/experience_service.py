from datetime import datetime, timedelta

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.economy import GiftTransaction, WalletLedger
from app.models.experience import ExperienceMutationReceipt, RoomExperienceStatus, UserExperienceStatus
from app.models.room_realtime_state import RoomRealtimeEvent
from app.models.room import Room
from app.models.user import User
from app.services import economy_rules_service
from app.services import level_progression_service as progression
from app.services.get_or_create_service import get_or_create_unique, get_or_create_unique_with_created

MAX_EXP_LEVEL = progression.MAX_LEVEL


def exp_required_for_level(level: int) -> int:
    return progression.exp_required_for_level(level, progression.ProgressionTrack.SEND)


def level_for_exp(total_exp: int) -> int:
    return progression.level_for_exp(total_exp, progression.ProgressionTrack.SEND)


def progress_payload(level: int, total_exp: int, track: progression.ProgressionTrack = progression.ProgressionTrack.SEND) -> dict:
    payload = progression.progress_payload(total_exp, track)
    # Keep backward compatibility for callers that still pass stored level.
    payload["stored_level"] = level
    return payload


def get_or_create_user_exp(db: Session, user_id: int) -> UserExperienceStatus:
    return get_or_create_unique(db, UserExperienceStatus, UserExperienceStatus.user_id, user_id)


def get_or_create_room_exp(db: Session, room_id: int) -> RoomExperienceStatus:
    return get_or_create_unique(db, RoomExperienceStatus, RoomExperienceStatus.room_id, room_id)


def apply_gift_exp(
    db: Session,
    *,
    sender_user_id: int,
    receiver_user_id: int,
    room_id: int | None,
    send_exp: int,
    receive_exp: int,
    room_exp: int,
    source_id: str,
) -> dict:
    receipt_key = f"GIFT_SETTLEMENT:{source_id}"
    receipt, created = get_or_create_unique_with_created(
        db,
        ExperienceMutationReceipt,
        ExperienceMutationReceipt.receipt_key,
        receipt_key,
    )
    if created:
        receipt.source_type = "GIFT_SETTLEMENT"
        receipt.source_id = source_id
        db.add(receipt)
    else:
        sender_status = get_or_create_user_exp(db, sender_user_id)
        receiver_status = get_or_create_user_exp(db, receiver_user_id)
        room_status = (
            get_or_create_room_exp(db, room_id)
            if room_id is not None and room_exp > 0
            else None
        )
        return {
            "sender": user_exp_payload(sender_status),
            "receiver": user_exp_payload(receiver_status),
            "room": room_exp_payload(room_status) if room_status else None,
            "duplicate": True,
        }

    sender_status = get_or_create_user_exp(db, sender_user_id)
    receiver_status = get_or_create_user_exp(db, receiver_user_id)

    sender_status.send_total_exp += max(send_exp, 0)
    sender_status.send_level = economy_rules_service.level_for_exp(
        db, sender_status.send_total_exp, "send"
    )
    sender_status.last_source_type = "GIFT_SEND"
    sender_status.last_source_id = source_id

    receiver_status.receive_total_exp += max(receive_exp, 0)
    receiver_status.receive_level = economy_rules_service.level_for_exp(
        db, receiver_status.receive_total_exp, "receive"
    )
    receiver_status.last_source_type = "GIFT_RECEIVE"
    receiver_status.last_source_id = source_id

    room_status = None
    if room_id is not None and room_exp > 0:
        room_status = get_or_create_room_exp(db, room_id)
        room_status.total_exp += max(room_exp, 0)
        room_status.level = economy_rules_service.level_for_exp(
            db, room_status.total_exp, "room"
        )
        room_status.last_source_type = "GIFT_RECEIVE"
        room_status.last_source_id = source_id

    return {
        "sender": user_exp_payload(sender_status),
        "receiver": user_exp_payload(receiver_status),
        "room": room_exp_payload(room_status) if room_status else None,
        "duplicate": False,
    }

def vip_svip_payload(*, lifetime_recharge_coin_exp: int, monthly_recharge_coin_exp: int) -> dict:
    return {
        "vip": progression.vip_payload(lifetime_recharge_coin_exp),
        "svip": progression.svip_payload(monthly_recharge_coin_exp),
        "rule": "VIP uses lifetime recharge coin EXP. SVIP uses monthly recharge coin EXP. Max target equals ₹5 crore worth of coins.",
    }


def user_exp_payload(status: UserExperienceStatus) -> dict:
    return {
        "user_id": status.user_id,
        "send": progress_payload(status.send_level, status.send_total_exp, progression.ProgressionTrack.SEND),
        "receive": progress_payload(status.receive_level, status.receive_total_exp, progression.ProgressionTrack.RECEIVE),
        "last_source_type": status.last_source_type,
        "last_source_id": status.last_source_id,
        "updated_at": status.updated_at.isoformat() if status.updated_at else None,
    }


def room_exp_payload(status: RoomExperienceStatus | None) -> dict | None:
    if status is None:
        return None
    return {
        "room_id": status.room_id,
        "room": progress_payload(status.level, status.total_exp, progression.ProgressionTrack.ROOM),
        "last_source_type": status.last_source_type,
        "last_source_id": status.last_source_id,
        "updated_at": status.updated_at.isoformat() if status.updated_at else None,
    }


def details_for_user(db: Session, user: User) -> dict:
    status = get_or_create_user_exp(db, user.id)
    return user_exp_payload(status)


def details_for_public_user_id(db: Session, public_user_id: int) -> dict | None:
    user = db.query(User).filter(User.public_user_id == public_user_id).first()
    if not user:
        return None
    status = get_or_create_user_exp(db, user.id)
    payload = user_exp_payload(status)
    payload["public_user_id"] = user.public_user_id
    payload["display_name"] = user.display_name or user.username
    return payload


def _room_details_payload(db: Session, room: Room) -> dict:
    status = get_or_create_room_exp(db, room.id)
    payload = room_exp_payload(status) or {}
    payload["room_public_id"] = room.room_public_id
    payload["room_name"] = room.name
    return payload


def details_for_room(db: Session, room_id: int) -> dict | None:
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room:
        return None
    return _room_details_payload(db, room)


def details_for_room_public_id(db: Session, room_public_id: str) -> dict | None:
    room = db.query(Room).filter(Room.room_public_id == room_public_id).first()
    if not room:
        return None
    return _room_details_payload(db, room)


_SOCIAL_MISSIONS = (
    {
        "id": "join_room",
        "title": "Drop into a room",
        "description": "Join one live room today.",
        "required": 1,
        "reward_coins": 10,
        "event_types": ("room.joined",),
    },
    {
        "id": "take_stage",
        "title": "Take the stage",
        "description": "Take a room seat once today.",
        "required": 1,
        "reward_coins": 15,
        "event_types": ("seat.taken",),
    },
    {
        "id": "room_activity",
        "title": "Start the party",
        "description": "Start one karaoke, party, or social-game activity today.",
        "required": 1,
        "reward_coins": 20,
        "event_types": ("room_activity.state.started",),
    },
    {
        "id": "send_gift",
        "title": "Share a reward",
        "description": "Send one gift today.",
        "required": 1,
        "reward_coins": 20,
        "event_types": (),
    },
)


def _utc_day_start(now: datetime | None = None) -> datetime:
    value = now or datetime.utcnow()
    return datetime(value.year, value.month, value.day)


def social_mission_cycle_key(now: datetime | None = None) -> str:
    return _utc_day_start(now).date().isoformat()


def social_missions_for_user(db: Session, user: User, now: datetime | None = None) -> list[dict]:
    start_at = _utc_day_start(now)
    cycle_key = social_mission_cycle_key(now)
    event_counts = {
        event_type: int(count or 0)
        for event_type, count in (
            db.query(RoomRealtimeEvent.event_type, func.count(RoomRealtimeEvent.id))
            .filter(
                RoomRealtimeEvent.actor_user_id == user.id,
                RoomRealtimeEvent.created_at >= start_at,
                RoomRealtimeEvent.event_type.in_(
                    [event for mission in _SOCIAL_MISSIONS for event in mission["event_types"]]
                ),
            )
            .group_by(RoomRealtimeEvent.event_type)
            .all()
        )
    }
    gift_count = int(
        db.query(func.count(GiftTransaction.id))
        .filter(
            GiftTransaction.sender_user_id == user.id,
            GiftTransaction.created_at >= start_at,
        )
        .scalar()
        or 0
    )
    claims = {
        str(source_id)
        for (source_id,) in (
            db.query(WalletLedger.source_id)
            .filter(
                WalletLedger.user_id == user.id,
                WalletLedger.source_type == "SOCIAL_MISSION_REWARD",
                WalletLedger.created_at >= start_at,
            )
            .all()
        )
        if source_id
    }

    result: list[dict] = []
    for definition in _SOCIAL_MISSIONS:
        if definition["id"] == "send_gift":
            progress = gift_count
        else:
            progress = sum(event_counts.get(event_type, 0) for event_type in definition["event_types"])
        required = int(definition["required"])
        source_id = f'{definition["id"]}:{cycle_key}'
        claimed = source_id in claims
        completed = progress >= required
        result.append(
            {
                "id": definition["id"],
                "title": definition["title"],
                "description": definition["description"],
                "progress": min(progress, required),
                "required": required,
                "completed": completed,
                "claimed": claimed,
                "claimable": completed and not claimed,
                "reward": {"currency": "COIN", "amount": int(definition["reward_coins"])},
                "cycle_key": cycle_key,
            }
        )
    return result


def community_events_for_user(db: Session, user: User, now: datetime | None = None) -> dict:
    current = now or datetime.utcnow()
    day_start = _utc_day_start(current)
    week_start = day_start - timedelta(days=day_start.weekday())
    if current.month == 12:
        next_month = datetime(current.year + 1, 1, 1)
    else:
        next_month = datetime(current.year, current.month + 1, 1)
    month_start = datetime(current.year, current.month, 1)
    missions = social_missions_for_user(db, user, current)
    claimed = sum(1 for item in missions if item["claimed"])
    return {
        "generated_at": current.isoformat(),
        "events": [
            {
                "id": f"social_sprint:{day_start.date().isoformat()}",
                "kind": "missions",
                "title": "Daily Social Sprint",
                "subtitle": "Rooms, stage time, party activities and gifts all count.",
                "status": "Live",
                "reward_text": f"{claimed}/{len(missions)} social rewards claimed",
                "starts_at": day_start.isoformat(),
                "ends_at": (day_start + timedelta(days=1)).isoformat(),
            },
            {
                "id": f"room_party:{week_start.date().isoformat()}",
                "kind": "rooms",
                "title": "Room Party Week",
                "subtitle": "Jump into live rooms, karaoke and social games with friends.",
                "status": "Live",
                "reward_text": "Room activity missions award coins",
                "starts_at": week_start.isoformat(),
                "ends_at": (week_start + timedelta(days=7)).isoformat(),
            },
            {
                "id": f"family_rally:{month_start.date().isoformat()}",
                "kind": "family",
                "title": "Family Rally",
                "subtitle": "Build your family through members, contribution and community activity.",
                "status": "Live",
                "reward_text": "Family rankings update from backend contribution data",
                "starts_at": month_start.isoformat(),
                "ends_at": next_month.isoformat(),
            },
        ],
        "missions": missions,
    }
