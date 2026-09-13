import json
import math
import secrets
from datetime import datetime, timedelta
from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.economy import EconomyCurrency, UserWallet
from app.models.lucky_packet import LuckyPacket, LuckyPacketClaim
from app.models.room import Room
from app.models.room_participant import RoomParticipant
from app.models.user import User
from app.services import economy_service

COUNTDOWN_SECONDS = 30
CLAIM_SECONDS = 20
RESULTS_SECONDS = 6
ACTIVE_STATUS = "ACTIVE"
COMPLETED_STATUS = "COMPLETED"
EXPIRED_STATUS = "EXPIRED"


def require_active_room_user(db: Session, room: Room, user_id: int) -> None:
    participant = (
        db.query(RoomParticipant)
        .filter(
            RoomParticipant.room_id == room.id,
            RoomParticipant.user_id == user_id,
            RoomParticipant.is_active.is_(True),
        )
        .first()
    )
    if participant is None:
        raise HTTPException(
            status_code=409,
            detail="Join the room before using Lucky Packet",
        )


def _lock_wallet(db: Session, user_id: int) -> UserWallet:
    wallet = (
        db.query(UserWallet)
        .filter(UserWallet.user_id == user_id)
        .with_for_update()
        .first()
    )
    if wallet is not None:
        return wallet
    wallet = economy_service.get_or_create_wallet(db, user_id)
    db.flush()
    return wallet


def _build_allocations(total: int, count: int) -> list[int]:
    if total <= 0 or count <= 0:
        raise ValueError("Lucky Packet amount and winner count must be positive")
    if total < count:
        raise ValueError("Lucky Packet needs at least 1 coin per winner")

    remaining = total
    allocations: list[int] = []
    rng = secrets.SystemRandom()
    for index in range(count - 1):
        slots_left = count - index
        average = max(1, remaining // slots_left)
        max_reward = min(
            remaining - (slots_left - 1),
            max(1, average * 2),
        )
        reward = rng.randint(1, max_reward)
        allocations.append(reward)
        remaining -= reward
    allocations.append(remaining)
    rng.shuffle(allocations)
    return allocations


def _allocations(packet: LuckyPacket) -> list[int]:
    try:
        parsed = json.loads(packet.allocation_json or "[]")
    except json.JSONDecodeError:
        parsed = []
    if not isinstance(parsed, list):
        return []
    return [int(value) for value in parsed if int(value) > 0]


def _phase(packet: LuckyPacket, now: datetime | None = None) -> tuple[str, int]:
    now = now or datetime.utcnow()
    if packet.status != ACTIVE_STATUS:
        return "results", RESULTS_SECONDS
    if now < packet.opens_at:
        seconds = max(0, math.ceil((packet.opens_at - now).total_seconds()))
        return "countdown", seconds
    if now < packet.closes_at and packet.claimed_count < packet.winner_count:
        seconds = max(0, math.ceil((packet.closes_at - now).total_seconds()))
        return "claim", seconds
    return "results", RESULTS_SECONDS


def _display_name(user: User) -> str:
    return user.display_name or user.username or f"User {user.public_user_id}"


def _room_user_id(user: User) -> str:
    return f"user_{user.public_user_id}"


def _claims_map(db: Session, packet_id: int) -> dict[str, int]:
    rows = (
        db.query(LuckyPacketClaim, User)
        .join(User, User.id == LuckyPacketClaim.user_id)
        .filter(LuckyPacketClaim.packet_id == packet_id)
        .order_by(LuckyPacketClaim.id.asc())
        .all()
    )
    result: dict[str, int] = {}
    for claim, user in rows:
        label = _display_name(user)
        if label in result:
            label = f"{label} · {user.public_user_id}"
        result[label] = int(claim.reward_coin_amount)
    return result


def _current_user_reward(db: Session, packet_id: int, user_id: int | None) -> int | None:
    if user_id is None:
        return None
    claim = (
        db.query(LuckyPacketClaim)
        .filter(
            LuckyPacketClaim.packet_id == packet_id,
            LuckyPacketClaim.user_id == user_id,
        )
        .first()
    )
    return int(claim.reward_coin_amount) if claim is not None else None


def snapshot(
    db: Session,
    packet: LuckyPacket,
    *,
    current_user_id: int | None = None,
    sender_coin_balance: int | None = None,
    wallet_coin_balance: int | None = None,
) -> dict:
    sender = db.query(User).filter(User.id == packet.sender_user_id).first()
    room = db.query(Room).filter(Room.id == packet.room_id).first()
    phase, remaining_seconds = _phase(packet)
    return {
        "packet_id": packet.public_id,
        "room_public_id": room.room_public_id if room is not None else "",
        "sender_user_id": _room_user_id(sender) if sender is not None else "",
        "sender_name": _display_name(sender) if sender is not None else "Vibe User",
        "coin_amount": int(packet.coin_amount),
        "winner_count": int(packet.winner_count),
        "message": packet.message or "",
        "phase": phase,
        "remaining_seconds": remaining_seconds,
        "claims": _claims_map(db, packet.id),
        "claimed_count": int(packet.claimed_count),
        "claimed_coin_amount": int(packet.claimed_coin_amount),
        "refunded_coin_amount": int(packet.refunded_coin_amount),
        "current_user_reward": _current_user_reward(db, packet.id, current_user_id),
        "sender_coin_balance": sender_coin_balance,
        "wallet_coin_balance": wallet_coin_balance,
        "created_at": packet.created_at.isoformat(),
    }


def _finalize_locked(db: Session, packet: LuckyPacket, now: datetime) -> bool:
    if packet.status != ACTIVE_STATUS:
        return False
    if now < packet.closes_at and packet.claimed_count < packet.winner_count:
        return False

    unclaimed = max(0, int(packet.coin_amount) - int(packet.claimed_coin_amount))
    if unclaimed > 0 and int(packet.refunded_coin_amount) == 0:
        sender_wallet = _lock_wallet(db, packet.sender_user_id)
        economy_service._credit_wallet(
            db,
            sender_wallet,
            EconomyCurrency.COIN,
            unclaimed,
            "LUCKY_PACKET_REFUND",
            packet.public_id,
            packet.sender_user_id,
            "Unclaimed Lucky Packet coins refunded",
        )
        packet.refunded_coin_amount = unclaimed

    packet.status = (
        COMPLETED_STATUS
        if packet.claimed_count >= packet.winner_count
        else EXPIRED_STATUS
    )
    packet.closed_at = now
    db.flush()
    return True


def create_packet(
    db: Session,
    *,
    room: Room,
    sender: User,
    coin_amount: int,
    winner_count: int,
    message: str,
) -> tuple[LuckyPacket, UserWallet, LuckyPacket | None]:
    if coin_amount < winner_count:
        raise HTTPException(
            status_code=400,
            detail="Lucky Packet needs at least 1 coin per winner",
        )

    locked_room = (
        db.query(Room)
        .filter(Room.id == room.id, Room.is_active.is_(True))
        .with_for_update()
        .first()
    )
    if locked_room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    require_active_room_user(db, locked_room, sender.id)

    now = datetime.utcnow()
    finalized_previous: LuckyPacket | None = None
    previous = (
        db.query(LuckyPacket)
        .filter(
            LuckyPacket.room_id == locked_room.id,
            LuckyPacket.status == ACTIVE_STATUS,
        )
        .order_by(LuckyPacket.id.desc())
        .with_for_update()
        .first()
    )
    if previous is not None:
        if _finalize_locked(db, previous, now):
            finalized_previous = previous
        else:
            raise HTTPException(
                status_code=409,
                detail="A Lucky Packet is already active in this room",
            )

    allocations = _build_allocations(coin_amount, winner_count)
    wallet = _lock_wallet(db, sender.id)
    if wallet.coin_balance < coin_amount:
        raise HTTPException(status_code=400, detail="Insufficient coins. Please recharge.")

    packet = LuckyPacket(
        public_id=f"lp_{uuid4().hex}",
        room_id=locked_room.id,
        sender_user_id=sender.id,
        coin_amount=coin_amount,
        winner_count=winner_count,
        message=message.strip(),
        status=ACTIVE_STATUS,
        allocation_json=json.dumps(allocations, separators=(",", ":")),
        opens_at=now + timedelta(seconds=COUNTDOWN_SECONDS),
        closes_at=now + timedelta(seconds=COUNTDOWN_SECONDS + CLAIM_SECONDS),
        created_at=now,
    )
    db.add(packet)
    db.flush()

    economy_service._debit_wallet(
        db,
        wallet,
        EconomyCurrency.COIN,
        coin_amount,
        "LUCKY_PACKET_FUND",
        packet.public_id,
        sender.id,
        f"Funded Lucky Packet for {winner_count} winners",
    )
    db.commit()
    db.refresh(packet)
    db.refresh(wallet)
    return packet, wallet, finalized_previous


def get_packet(db: Session, packet_public_id: str) -> LuckyPacket:
    packet = (
        db.query(LuckyPacket)
        .filter(LuckyPacket.public_id == packet_public_id)
        .first()
    )
    if packet is None:
        raise HTTPException(status_code=404, detail="Lucky Packet not found")
    return packet


def get_active_packet(db: Session, room: Room) -> LuckyPacket | None:
    packet = (
        db.query(LuckyPacket)
        .filter(
            LuckyPacket.room_id == room.id,
            LuckyPacket.status == ACTIVE_STATUS,
        )
        .order_by(LuckyPacket.id.desc())
        .first()
    )
    if packet is None:
        return None
    if datetime.utcnow() >= packet.closes_at:
        locked = (
            db.query(LuckyPacket)
            .filter(LuckyPacket.id == packet.id)
            .with_for_update()
            .first()
        )
        if locked is not None and _finalize_locked(db, locked, datetime.utcnow()):
            db.commit()
            db.refresh(locked)
            return locked
    return packet


def claim_packet(
    db: Session,
    *,
    packet_public_id: str,
    user: User,
) -> tuple[LuckyPacket, LuckyPacketClaim | None, UserWallet | None, bool, bool]:
    packet = (
        db.query(LuckyPacket)
        .filter(LuckyPacket.public_id == packet_public_id)
        .with_for_update()
        .first()
    )
    if packet is None:
        raise HTTPException(status_code=404, detail="Lucky Packet not found")

    room = db.query(Room).filter(Room.id == packet.room_id).first()
    if room is None or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    require_active_room_user(db, room, user.id)

    existing = (
        db.query(LuckyPacketClaim)
        .filter(
            LuckyPacketClaim.packet_id == packet.id,
            LuckyPacketClaim.user_id == user.id,
        )
        .first()
    )
    if existing is not None:
        wallet = _lock_wallet(db, user.id)
        return packet, existing, wallet, False, False

    now = datetime.utcnow()
    if now < packet.opens_at:
        raise HTTPException(status_code=409, detail="Lucky Packet is not open yet")

    if now >= packet.closes_at or packet.status != ACTIVE_STATUS:
        finalized = _finalize_locked(db, packet, now)
        if finalized:
            db.commit()
            db.refresh(packet)
        return packet, None, None, False, finalized

    if packet.claimed_count >= packet.winner_count:
        finalized = _finalize_locked(db, packet, now)
        if finalized:
            db.commit()
            db.refresh(packet)
        return packet, None, None, False, finalized

    allocations = _allocations(packet)
    if len(allocations) != packet.winner_count:
        raise HTTPException(status_code=500, detail="Lucky Packet allocation is invalid")
    reward = int(allocations[packet.claimed_count])

    wallet = _lock_wallet(db, user.id)
    economy_service._credit_wallet(
        db,
        wallet,
        EconomyCurrency.COIN,
        reward,
        "LUCKY_PACKET_CLAIM",
        packet.public_id,
        packet.sender_user_id,
        "Lucky Packet reward",
    )
    claim = LuckyPacketClaim(
        packet_id=packet.id,
        user_id=user.id,
        reward_coin_amount=reward,
        created_at=now,
    )
    db.add(claim)
    packet.claimed_count += 1
    packet.claimed_coin_amount += reward
    db.flush()

    finalized = _finalize_locked(db, packet, now)
    db.commit()
    db.refresh(packet)
    db.refresh(claim)
    db.refresh(wallet)
    return packet, claim, wallet, True, finalized


def finalize_packet(
    db: Session,
    *,
    packet_public_id: str,
    user: User,
) -> tuple[LuckyPacket, bool]:
    packet = (
        db.query(LuckyPacket)
        .filter(LuckyPacket.public_id == packet_public_id)
        .with_for_update()
        .first()
    )
    if packet is None:
        raise HTTPException(status_code=404, detail="Lucky Packet not found")
    room = db.query(Room).filter(Room.id == packet.room_id).first()
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    require_active_room_user(db, room, user.id)

    changed = _finalize_locked(db, packet, datetime.utcnow())
    if changed:
        db.commit()
        db.refresh(packet)
    return packet, changed


def room_event_payload(
    db: Session,
    packet: LuckyPacket,
    *,
    event_type: str,
    target_claim: LuckyPacketClaim | None = None,
) -> dict:
    room = db.query(Room).filter(Room.id == packet.room_id).first()
    sender = db.query(User).filter(User.id == packet.sender_user_id).first()
    target_user = (
        db.query(User).filter(User.id == target_claim.user_id).first()
        if target_claim is not None
        else None
    )
    phase, remaining_seconds = _phase(packet)
    suffix = target_claim.id if target_claim is not None else packet.claimed_count
    return {
        "type": "room/system_event",
        "payload": {
            "id": f"lucky_packet_{packet.public_id}_{event_type}_{suffix}",
            "event_type": event_type,
            "type": event_type,
            "room_id": room.room_public_id if room is not None else "",
            "actor_user_id": _room_user_id(sender) if sender is not None else "",
            "actor_name": _display_name(sender) if sender is not None else "Vibe User",
            "target_user_id": _room_user_id(target_user) if target_user is not None else "",
            "target_name": _display_name(target_user) if target_user is not None else "",
            "message": "",
            "gift_id": packet.public_id,
            "gift_name": packet.message or "",
            "gift_category": phase,
            "gift_type": "lucky_packet",
            "quantity": packet.winner_count,
            "coin_value": 0,
            "total_coin_value": packet.coin_amount,
            "lucky_reward_coin_amount": int(target_claim.reward_coin_amount)
            if target_claim is not None
            else 0,
            "auto_dismiss_seconds": remaining_seconds,
            "show_gift_slide": False,
            "show_premium_broadcast": False,
            "show_gift_flight": False,
            "broadcast_scope": "room",
            "created_at": packet.created_at.isoformat(),
        },
    }
