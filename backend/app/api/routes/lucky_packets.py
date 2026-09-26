from datetime import datetime
from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from fastapi.responses import JSONResponse
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
from app.services import (
    economy_service_client,
    economy_transaction_service,
    lucky_packet_service,
)

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


def _begin_public(
    db: Session,
    *,
    operation: str,
    business_reference: str,
    actor_user_id: int,
    request_payload: dict,
):
    context = economy_service_client.mutation_context(operation, business_reference)
    return economy_transaction_service.begin(
        db,
        transaction_id=context["transaction_id"],
        idempotency_key=context["idempotency_key"],
        business_reference=context["business_reference"],
        operation_type=operation,
        actor_user_id=actor_user_id,
        request_payload=request_payload,
    )


def _queue_packet_broadcast(
    background_tasks: BackgroundTasks,
    db: Session,
    packet,
    *,
    event_type: str,
    target_claim: LuckyPacketClaim | None = None,
) -> None:
    # This adapter publishes to the canonical Go realtime gateway after the
    # authoritative Economy transaction has committed. Missing realtime is
    # recoverable from the bounded REST snapshot.
    room = db.query(Room).filter(Room.id == packet.room_id).first()
    if room is None:
        return
    event_payload = lucky_packet_service.room_event_payload(
        db,
        packet,
        event_type=event_type,
        target_claim=target_claim,
    )
    background_tasks.add_task(
        room_realtime_connections.broadcast_room,
        room.room_public_id,
        event_payload,
    )


@router.post("", response_model=LuckyPacketResponse)
def create_lucky_packet(
    payload: LuckyPacketCreateRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    request_id = (payload.request_id or str(uuid4())).strip()
    business_reference = f"lucky-packet-create:{current_user.id}:{request_id}"
    tx, cached = _begin_public(
        db,
        operation="lucky_packet.create",
        business_reference=business_reference,
        actor_user_id=current_user.id,
        request_payload={
            "sender_user_id": current_user.id,
            **payload.model_dump(),
            "request_id": request_id,
        },
    )
    if cached is not None:
        return LuckyPacketResponse(**cached)

    room = _room_from_public_id(db, payload.room_public_id)
    packet, wallet, finalized_previous = lucky_packet_service.create_packet(
        db,
        room=room,
        sender=current_user,
        coin_amount=payload.coin_amount,
        winner_count=payload.winner_count,
        message=payload.message,
        tx=tx,
    )
    result = LuckyPacketResponse(
        **lucky_packet_service.snapshot(
            db,
            packet,
            current_user_id=current_user.id,
            sender_coin_balance=int(wallet.coin_balance),
            wallet_coin_balance=int(wallet.coin_balance),
        )
    ).model_dump(mode="json")
    economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.lucky_packet.created.v1",
        event_payload={
            "packet_id": packet.public_id,
            "room_id": room.room_public_id,
            "sender_user_id": current_user.id,
            "coin_amount": payload.coin_amount,
            "winner_count": payload.winner_count,
        },
    )

    if finalized_previous is not None:
        _queue_packet_broadcast(
            background_tasks,
            db,
            finalized_previous,
            event_type="lucky_packet_results",
        )
    _queue_packet_broadcast(
        background_tasks,
        db,
        packet,
        event_type="lucky_packet_created",
    )
    return LuckyPacketResponse(**result)


@router.get("/active", response_model=LuckyPacketResponse | None)
def get_active_lucky_packet(
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
def get_lucky_packet(
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
def claim_lucky_packet(
    packet_public_id: str,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    business_reference = f"lucky-packet-claim:{packet_public_id}:{current_user.id}"
    tx, cached = _begin_public(
        db,
        operation="lucky_packet.claim",
        business_reference=business_reference,
        actor_user_id=current_user.id,
        request_payload={
            "packet_public_id": packet_public_id,
            "user_id": current_user.id,
        },
    )
    if cached is not None:
        if cached.get("_closed") is True:
            return JSONResponse(status_code=410, content={"detail": "Lucky Packet is closed"})
        return LuckyPacketClaimResponse(**cached)

    packet, claim, wallet, created, finalized = lucky_packet_service.claim_packet(
        db,
        packet_public_id=packet_public_id,
        user=current_user,
        tx=tx,
    )

    if claim is None:
        economy_transaction_service.complete(
            db,
            tx=tx,
            result={"_closed": True, "packet_id": packet.public_id},
            event_type="economy.lucky_packet.closed_claim.v1",
            event_payload={
                "packet_id": packet.public_id,
                "user_id": current_user.id,
                "finalized": finalized,
            },
        )
        if finalized:
            _queue_packet_broadcast(
                background_tasks,
                db,
                packet,
                event_type="lucky_packet_results",
            )
        return JSONResponse(
            status_code=410,
            content={"detail": "Lucky Packet is closed"},
            background=background_tasks if background_tasks.tasks else None,
        )

    result = LuckyPacketClaimResponse(
        **lucky_packet_service.snapshot(
            db,
            packet,
            current_user_id=current_user.id,
            wallet_coin_balance=int(wallet.coin_balance) if wallet is not None else None,
        )
    ).model_dump(mode="json")
    economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type=(
            "economy.lucky_packet.claimed.v1"
            if created
            else "economy.lucky_packet.claim_duplicate.v1"
        ),
        event_payload={
            "packet_id": packet.public_id,
            "user_id": current_user.id,
            "reward_coin_amount": int(claim.reward_coin_amount),
            "created": created,
            "finalized": finalized,
        },
    )

    if created:
        _queue_packet_broadcast(
            background_tasks,
            db,
            packet,
            event_type="lucky_packet_claimed",
            target_claim=claim,
        )
    if finalized:
        _queue_packet_broadcast(
            background_tasks,
            db,
            packet,
            event_type="lucky_packet_results",
        )
    return LuckyPacketClaimResponse(**result)


@router.post("/{packet_public_id}/finalize", response_model=LuckyPacketResponse)
def finalize_lucky_packet(
    packet_public_id: str,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    preflight = lucky_packet_service.get_packet(db, packet_public_id)
    room = db.query(Room).filter(Room.id == preflight.room_id).first()
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    lucky_packet_service.require_active_room_user(db, room, current_user.id)

    now = datetime.utcnow()
    if (
        preflight.status != lucky_packet_service.ACTIVE_STATUS
        or (
            now < preflight.closes_at
            and preflight.claimed_count < preflight.winner_count
        )
    ):
        return LuckyPacketResponse(
            **lucky_packet_service.snapshot(
                db,
                preflight,
                current_user_id=current_user.id,
            )
        )

    business_reference = (
        f"lucky-packet-finalize:{packet_public_id}:"
        f"{preflight.claimed_count}:{preflight.refunded_coin_amount}"
    )
    tx, cached = _begin_public(
        db,
        operation="lucky_packet.finalize",
        business_reference=business_reference,
        actor_user_id=current_user.id,
        request_payload={
            "packet_public_id": packet_public_id,
            "claimed_count": int(preflight.claimed_count),
            "refunded_coin_amount": int(preflight.refunded_coin_amount),
        },
    )
    if cached is not None:
        return LuckyPacketResponse(**cached)

    packet, changed = lucky_packet_service.finalize_packet(
        db,
        packet_public_id=packet_public_id,
        user=current_user,
        tx=tx,
    )
    result = LuckyPacketResponse(
        **lucky_packet_service.snapshot(
            db,
            packet,
            current_user_id=current_user.id,
        )
    ).model_dump(mode="json")
    economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.lucky_packet.finalized.v1",
        event_payload={
            "packet_id": packet.public_id,
            "actor_user_id": current_user.id,
            "changed": changed,
            "refunded_coin_amount": int(packet.refunded_coin_amount or 0),
        },
    )
    if changed:
        _queue_packet_broadcast(
            background_tasks,
            db,
            packet,
            event_type="lucky_packet_results",
        )
    return LuckyPacketResponse(**result)
