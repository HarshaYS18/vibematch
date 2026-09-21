from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.lucky_packet import LuckyPacketClaim
from app.models.room import Room
from app.models.user import User
from app.realtime.connection_manager import room_realtime_connections
from app.schemas.lucky_packet import (
    LuckyPacketClaimResponse,
    LuckyPacketCreateRequest,
    LuckyPacketResponse,
)
from app.services import lucky_packet_service

router = APIRouter(prefix="/lucky-packets", tags=["Lucky Packets"])


def _room_from_public_id(db: Session, room_public_id: str) -> Room:
    clean = room_public_id.strip()
    room = (
        db.query(Room)
        .filter(Room.room_public_id == clean, Room.is_active.is_(True))
        .first()
    )
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    return room


async def _broadcast_packet(
    db: Session,
    packet,
    *,
    event_type: str,
    target_claim: LuckyPacketClaim | None = None,
) -> None:
    room = db.query(Room).filter(Room.id == packet.room_id).first()
    if room is None:
        return
    await room_realtime_connections.broadcast_room(
        room.room_public_id,
        lucky_packet_service.room_event_payload(
            db,
            packet,
            event_type=event_type,
            target_claim=target_claim,
        ),
    )


@router.post("", response_model=LuckyPacketResponse)
async def create_lucky_packet(
    payload: LuckyPacketCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    room = _room_from_public_id(db, payload.room_public_id)
    packet, wallet, finalized_previous = lucky_packet_service.create_packet(
        db,
        room=room,
        sender=current_user,
        coin_amount=payload.coin_amount,
        winner_count=payload.winner_count,
        message=payload.message,
    )
    if finalized_previous is not None:
        await _broadcast_packet(
            db,
            finalized_previous,
            event_type="lucky_packet_results",
        )
    await _broadcast_packet(db, packet, event_type="lucky_packet_created")
    return LuckyPacketResponse(
        **lucky_packet_service.snapshot(
            db,
            packet,
            current_user_id=current_user.id,
            sender_coin_balance=int(wallet.coin_balance),
            wallet_coin_balance=int(wallet.coin_balance),
        )
    )


@router.get("/active", response_model=LuckyPacketResponse | None)
async def get_active_lucky_packet(
    room_public_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    room = _room_from_public_id(db, room_public_id)
    lucky_packet_service.require_active_room_user(db, room, current_user.id)
    packet = lucky_packet_service.get_active_packet(db, room)
    if packet is None:
        return None
    return LuckyPacketResponse(
        **lucky_packet_service.snapshot(
            db,
            packet,
            current_user_id=current_user.id,
        )
    )


@router.get("/{packet_public_id}", response_model=LuckyPacketResponse)
async def get_lucky_packet(
    packet_public_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    packet = lucky_packet_service.get_packet(db, packet_public_id)
    room = db.query(Room).filter(Room.id == packet.room_id).first()
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    lucky_packet_service.require_active_room_user(db, room, current_user.id)
    return LuckyPacketResponse(
        **lucky_packet_service.snapshot(
            db,
            packet,
            current_user_id=current_user.id,
        )
    )


@router.post("/{packet_public_id}/claim", response_model=LuckyPacketClaimResponse)
async def claim_lucky_packet(
    packet_public_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    packet, claim, wallet, created, finalized = lucky_packet_service.claim_packet(
        db,
        packet_public_id=packet_public_id,
        user=current_user,
    )

    if claim is None:
        if finalized:
            await _broadcast_packet(db, packet, event_type="lucky_packet_results")
        raise HTTPException(status_code=410, detail="Lucky Packet is closed")

    if created:
        await _broadcast_packet(
            db,
            packet,
            event_type="lucky_packet_claimed",
            target_claim=claim,
        )
    if finalized:
        await _broadcast_packet(db, packet, event_type="lucky_packet_results")

    return LuckyPacketClaimResponse(
        **lucky_packet_service.snapshot(
            db,
            packet,
            current_user_id=current_user.id,
            wallet_coin_balance=int(wallet.coin_balance) if wallet is not None else None,
        )
    )


@router.post("/{packet_public_id}/finalize", response_model=LuckyPacketResponse)
async def finalize_lucky_packet(
    packet_public_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    packet, changed = lucky_packet_service.finalize_packet(
        db,
        packet_public_id=packet_public_id,
        user=current_user,
    )
    if changed:
        await _broadcast_packet(db, packet, event_type="lucky_packet_results")
    return LuckyPacketResponse(
        **lucky_packet_service.snapshot(
            db,
            packet,
            current_user_id=current_user.id,
        )
    )
