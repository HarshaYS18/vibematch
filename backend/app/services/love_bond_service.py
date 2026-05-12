from datetime import datetime
from uuid import uuid4

from sqlalchemy.orm import Session

from app.models.inbox import InboxMessageType
from app.models.love_bond import (
    LoveBond,
    LoveBondCardType,
    LoveBondInventory,
    LoveBondRequest,
    LoveBondRequestStatus,
    LoveBondStatus,
)
from app.models.user import User
from app.services.inbox_service import create_direct_conversation, send_message


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
    existing = {
        item.card_type: item
        for item in db.query(LoveBondInventory).filter(
            LoveBondInventory.user_id == user.id,
            LoveBondInventory.is_active.is_(True),
        )
    }

    created = False
    for card_type, card_name in DEFAULT_CARD_NAMES.items():
        if card_type in existing:
            continue
        db.add(
            LoveBondInventory(
                user_id=user.id,
                card_type=card_type,
                card_name=card_name,
                quantity=1,
                reserved_quantity=0,
                source="default_seed",
            )
        )
        created = True

    if created:
        db.commit()

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
    seed_inventory(db, user)
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


def _available_quantity(item: LoveBondInventory) -> int:
    return max(0, item.quantity - item.reserved_quantity)


def send_love_bond_request(
    db: Session,
    sender: User,
    receiver: User,
    card_type: str,
) -> LoveBondRequest:
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

    conversation = create_direct_conversation(db, sender, receiver)
    sender_name = _display_name(sender)
    message_text = f"{sender_name} wants to be your {card_name}."

    message = send_message(
        db=db,
        conversation=conversation,
        sender=sender,
        text=message_text,
        message_type=InboxMessageType.RELATIONSHIP_REQUEST.value,
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

    request.inbox_message_id = message.id
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

    if request.inbox_message:
        metadata = dict(request.inbox_message.metadata_json or {})
        metadata["status"] = LoveBondRequestStatus.ACCEPTED.value
        request.inbox_message.metadata_json = metadata
        request.inbox_message.text = f"You accepted {_display_name(request.sender)}'s {request.card_name} request."

    db.commit()
    db.refresh(bond)
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

    if request.inbox_message:
        metadata = dict(request.inbox_message.metadata_json or {})
        metadata["status"] = LoveBondRequestStatus.REJECTED.value
        request.inbox_message.metadata_json = metadata
        request.inbox_message.text = f"You rejected {_display_name(request.sender)}'s {request.card_name} request."

    db.commit()
    db.refresh(request)
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
