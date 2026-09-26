from datetime import datetime
from uuid import uuid4
from datetime import timedelta

from sqlalchemy.orm import Session

from app.models.love_bond import (
    LoveBond,
    LoveBondCardType,
    LoveBondInventory,
    LoveBondRequest,
    LoveBondRequestStatus,
    LoveBondStatus,
)
from app.models.user import User
from app.services import inbox_service_client


DEFAULT_CARD_NAMES = {
    LoveBondCardType.LOVE.value: "Love",
    LoveBondCardType.BESTIE.value: "Bestie",
    LoveBondCardType.SIBLING.value: "Sibling",
}


def _public_id(prefix: str) -> str:
    return f"{prefix}_{uuid4().hex[:20]}"


def _display_name(user: User) -> str:
    return user.display_name or user.username or f"User {user.public_user_id}"


def normalize_card_type(card_type: str) -> str:
    normalized = card_type.strip().lower()
    if normalized in {"love", "lover"}:
        return LoveBondCardType.LOVE.value
    if normalized in {"bestie", "best_friend", "friend"}:
        return LoveBondCardType.BESTIE.value
    if normalized in {"sibling", "brother", "sister"}:
        return LoveBondCardType.SIBLING.value
    raise ValueError("Invalid relationship card type.")


def display_card_name(card_type: str) -> str:
    return DEFAULT_CARD_NAMES.get(normalize_card_type(card_type), "Relationship")


def seed_inventory(db: Session, user: User) -> list[LoveBondInventory]:
    return list_inventory(db, user)


def list_inventory(db: Session, user: User) -> list[LoveBondInventory]:
    return (
        db.query(LoveBondInventory)
        .filter(
            LoveBondInventory.user_id == user.id,
            LoveBondInventory.is_active.is_(True),
        )
        .order_by(LoveBondInventory.card_type.asc())
        .all()
    )


def _inventory_item_for_update(db: Session, user: User, card_type: str) -> LoveBondInventory:
    normalized = normalize_card_type(card_type)
    item = (
        db.query(LoveBondInventory)
        .filter(
            LoveBondInventory.user_id == user.id,
            LoveBondInventory.card_type == normalized,
            LoveBondInventory.is_active.is_(True),
        )
        .with_for_update()
        .first()
    )
    if item is None:
        raise ValueError("Relationship card not found in inventory.")
    return item


def grant_inventory_card(
    db: Session,
    user: User,
    card_type: str,
    quantity: int = 1,
    source: str = "store_purchase",
) -> LoveBondInventory:
    normalized = normalize_card_type(card_type)
    if quantity <= 0:
        raise ValueError("Quantity must be positive.")
    item = (
        db.query(LoveBondInventory)
        .filter(
            LoveBondInventory.user_id == user.id,
            LoveBondInventory.card_type == normalized,
            LoveBondInventory.is_active.is_(True),
        )
        .with_for_update()
        .first()
    )
    if item is None:
        item = LoveBondInventory(
            user_id=user.id,
            card_type=normalized,
            card_name=display_card_name(normalized),
            quantity=0,
            reserved_quantity=0,
            source=source,
        )
        db.add(item)
        db.flush()
    item.quantity += quantity
    item.source = source
    return item


def _patch_request_message(
    request: LoveBondRequest,
    *,
    text: str,
    status: str,
    extra_metadata: dict | None = None,
) -> None:
    message_id = (request.inbox_message_public_id or "").strip()
    if not message_id:
        return
    metadata = {"status": status}
    metadata.update(extra_metadata or {})
    try:
        inbox_service_client.patch_message(
            message_id,
            text=text,
            metadata_patch=metadata,
        )
    except (inbox_service_client.InboxServiceUnavailable, ValueError):
        # Relationship state is authoritative here. A later reconciliation
        # pass may repair the Inbox presentation if the service was unavailable.
        return


def expire_stale_requests(db: Session, user: User | None = None) -> int:
    cutoff = datetime.utcnow() - timedelta(hours=24)
    query = db.query(LoveBondRequest).filter(
        LoveBondRequest.status == LoveBondRequestStatus.PENDING.value,
        LoveBondRequest.created_at <= cutoff,
    )
    if user is not None:
        query = query.filter(
            (LoveBondRequest.sender_user_id == user.id)
            | (LoveBondRequest.receiver_user_id == user.id)
        )
    expired = query.with_for_update().all()
    patches: list[tuple[LoveBondRequest, str]] = []
    for request in expired:
        item = (
            db.query(LoveBondInventory)
            .filter(
                LoveBondInventory.user_id == request.sender_user_id,
                LoveBondInventory.card_type == request.card_type,
                LoveBondInventory.is_active.is_(True),
            )
            .with_for_update()
            .first()
        )
        if item is not None and item.reserved_quantity > 0:
            item.reserved_quantity -= 1
        request.status = LoveBondRequestStatus.CANCELLED.value
        request.responded_at = datetime.utcnow()
        patches.append(
            (
                request,
                f"{request.card_name} request expired. The card returned to inventory.",
            )
        )
    if expired:
        db.commit()
        for request, text in patches:
            _patch_request_message(
                request,
                text=text,
                status=LoveBondRequestStatus.CANCELLED.value,
                extra_metadata={"expired_after_hours": 24},
            )
    return len(expired)


def _available_quantity(item: LoveBondInventory) -> int:
    return max(0, item.quantity - item.reserved_quantity)


def send_love_bond_request(
    db: Session,
    sender: User,
    receiver: User,
    card_type: str,
) -> LoveBondRequest:
    expire_stale_requests(db, sender)
    if sender.id == receiver.id:
        raise ValueError("You cannot send a relationship card to yourself.")

    normalized = normalize_card_type(card_type)
    card_name = display_card_name(normalized)

    pending = (
        db.query(LoveBondRequest)
        .filter(
            LoveBondRequest.sender_user_id == sender.id,
            LoveBondRequest.receiver_user_id == receiver.id,
            LoveBondRequest.card_type == normalized,
            LoveBondRequest.status == LoveBondRequestStatus.PENDING.value,
        )
        .first()
    )
    if pending:
        raise ValueError("A relationship request is already pending.")

    existing_active = (
        db.query(LoveBond)
        .filter(
            LoveBond.status == LoveBondStatus.ACTIVE.value,
            LoveBond.card_type == normalized,
            (
                ((LoveBond.user_a_id == sender.id) & (LoveBond.user_b_id == receiver.id))
                | ((LoveBond.user_a_id == receiver.id) & (LoveBond.user_b_id == sender.id))
            ),
        )
        .first()
    )
    if existing_active:
        raise ValueError("This relationship already exists.")

    item = _inventory_item_for_update(db, sender, normalized)
    if _available_quantity(item) <= 0:
        raise ValueError("You do not have this relationship card available.")

    item.reserved_quantity += 1

    request = LoveBondRequest(
        public_id=_public_id("bond_req"),
        sender_user_id=sender.id,
        receiver_user_id=receiver.id,
        card_type=normalized,
        card_name=card_name,
        status=LoveBondRequestStatus.PENDING.value,
    )
    db.add(request)
    db.flush()

    sender_name = _display_name(sender)
    message_text = f"{sender_name} wants to be your {card_name}."
    db.commit()
    db.refresh(request)

    try:
        delivered = inbox_service_client.send_direct_message(
            sender_user_id=sender.id,
            target_user_id=receiver.id,
            text=message_text,
            message_type="relationship_request",
            metadata={
                "action": "love_bond_request",
                "love_bond_request_id": request.public_id,
                "card_type": normalized,
                "card_name": card_name,
                "sender_user_id": sender.id,
                "sender_public_user_id": sender.public_user_id,
                "receiver_user_id": receiver.id,
                "receiver_public_user_id": receiver.public_user_id,
                "status": LoveBondRequestStatus.PENDING.value,
            },
        )
    except (inbox_service_client.InboxServiceUnavailable, ValueError) as exc:
        failed_item = _inventory_item_for_update(db, sender, normalized)
        if failed_item.reserved_quantity > 0:
            failed_item.reserved_quantity -= 1
        request.status = LoveBondRequestStatus.CANCELLED.value
        request.responded_at = datetime.utcnow()
        db.add(request)
        db.commit()
        raise ValueError("Unable to deliver relationship request right now.") from exc

    request.inbox_message_public_id = str(delivered.get("message_id") or "") or None
    db.add(request)
    db.commit()
    db.refresh(request)
    return request


def accept_love_bond_request(db: Session, current_user: User, request_public_id: str) -> LoveBond:
    request = (
        db.query(LoveBondRequest)
        .filter(LoveBondRequest.public_id == request_public_id)
        .with_for_update()
        .first()
    )
    if request is None:
        raise ValueError("Relationship request not found.")

    if request.receiver_user_id != current_user.id:
        raise PermissionError("Only the receiver can accept this request.")

    if request.status != LoveBondRequestStatus.PENDING.value:
        raise ValueError("This relationship request is no longer pending.")

    item = _inventory_item_for_update(db, request.sender, request.card_type)
    if item.reserved_quantity > 0:
        item.reserved_quantity -= 1
    if item.quantity > 0:
        item.quantity -= 1

    request.status = LoveBondRequestStatus.ACCEPTED.value
    request.responded_at = datetime.utcnow()

    user_a_id, user_b_id = sorted([request.sender_user_id, request.receiver_user_id])
    bond = LoveBond(
        public_id=_public_id("bond"),
        request_id=request.id,
        user_a_id=user_a_id,
        user_b_id=user_b_id,
        card_type=request.card_type,
        status=LoveBondStatus.ACTIVE.value,
        love_score=0,
        level=1,
    )
    db.add(bond)

    db.commit()
    db.refresh(bond)
    _patch_request_message(
        request,
        text=f"You accepted {_display_name(request.sender)}'s {request.card_name} request.",
        status=LoveBondRequestStatus.ACCEPTED.value,
    )
    return bond


def reject_love_bond_request(db: Session, current_user: User, request_public_id: str) -> LoveBondRequest:
    request = (
        db.query(LoveBondRequest)
        .filter(LoveBondRequest.public_id == request_public_id)
        .with_for_update()
        .first()
    )
    if request is None:
        raise ValueError("Relationship request not found.")

    if request.receiver_user_id != current_user.id:
        raise PermissionError("Only the receiver can reject this request.")

    if request.status != LoveBondRequestStatus.PENDING.value:
        raise ValueError("This relationship request is no longer pending.")

    item = _inventory_item_for_update(db, request.sender, request.card_type)
    if item.reserved_quantity > 0:
        item.reserved_quantity -= 1

    request.status = LoveBondRequestStatus.REJECTED.value
    request.responded_at = datetime.utcnow()

    db.commit()
    db.refresh(request)
    _patch_request_message(
        request,
        text=f"You rejected {_display_name(request.sender)}'s {request.card_name} request.",
        status=LoveBondRequestStatus.REJECTED.value,
    )
    return request


def list_active_bonds_for_user(db: Session, user: User) -> list[LoveBond]:
    return (
        db.query(LoveBond)
        .filter(
            LoveBond.status == LoveBondStatus.ACTIVE.value,
            ((LoveBond.user_a_id == user.id) | (LoveBond.user_b_id == user.id)),
        )
        .order_by(LoveBond.started_at.desc())
        .all()
    )


def inventory_to_dict(item: LoveBondInventory) -> dict:
    return {
        "card_type": item.card_type,
        "card_name": item.card_name,
        "quantity": item.quantity,
        "reserved_quantity": item.reserved_quantity,
        "available_quantity": _available_quantity(item),
        "source": item.source,
    }


def request_to_dict(request: LoveBondRequest) -> dict:
    return {
        "id": request.public_id,
        "sender_public_user_id": request.sender.public_user_id,
        "sender_name": _display_name(request.sender),
        "receiver_public_user_id": request.receiver.public_user_id,
        "receiver_name": _display_name(request.receiver),
        "card_type": request.card_type,
        "card_name": request.card_name,
        "status": request.status,
        "created_at": request.created_at.isoformat() if request.created_at else None,
        "responded_at": request.responded_at.isoformat() if request.responded_at else None,
    }


def bond_to_dict(bond: LoveBond, viewer: User) -> dict:
    partner = bond.user_b if bond.user_a_id == viewer.id else bond.user_a
    return {
        "id": bond.public_id,
        "card_type": bond.card_type,
        "status": bond.status,
        "love_score": bond.love_score,
        "level": bond.level,
        "partner_public_user_id": partner.public_user_id,
        "partner_name": _display_name(partner),
        "partner_avatar_url": partner.avatar_url,
        "partner_gender": partner.gender,
        "started_at": bond.started_at.isoformat() if bond.started_at else None,
    }
