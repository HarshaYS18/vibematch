from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.love_bond import LoveBondRequest, LoveBondRequestStatus
from app.models.user import User
from app.schemas.love_bond import (
    LoveBondInventoryResponse,
    LoveBondListResponse,
    LoveBondRequestListResponse,
    LoveBondRequestResponse,
    LoveBondResponse,
    LoveBondSendRequest,
)
from app.services import love_bond_service
from app.websocket.inbox_ws import inbox_ws_manager

router = APIRouter(prefix="/love-bonds", tags=["Love Bonds"])


@router.get("/inventory", response_model=LoveBondInventoryResponse)
def get_my_love_bond_inventory(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    items = love_bond_service.seed_inventory(db, current_user)
    return LoveBondInventoryResponse(
        items=[love_bond_service.inventory_to_dict(item) for item in items],
    )


@router.post("/requests", response_model=LoveBondRequestResponse)
async def send_love_bond_request(
    request: LoveBondSendRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    receiver = (
        db.query(User)
        .filter(
            User.public_user_id == request.receiver_public_user_id,
            User.is_active.is_(True),
        )
        .first()
    )
    if receiver is None:
        raise HTTPException(status_code=404, detail="Receiver user not found.")

    try:
        bond_request = love_bond_service.send_love_bond_request(
            db=db,
            sender=current_user,
            receiver=receiver,
            card_type=request.card_type,
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error

    if bond_request.inbox_message is not None:
        await inbox_ws_manager.broadcast_to_users(
            [current_user.id, receiver.id],
            {
                "event": "inbox_conversation_updated",
                "conversation_id": bond_request.inbox_message.conversation.public_id,
            },
        )

    return LoveBondRequestResponse(**love_bond_service.request_to_dict(bond_request))


@router.get("/requests/pending", response_model=LoveBondRequestListResponse)
def list_pending_love_bond_requests(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    requests = (
        db.query(LoveBondRequest)
        .filter(
            LoveBondRequest.receiver_user_id == current_user.id,
            LoveBondRequest.status == LoveBondRequestStatus.PENDING.value,
        )
        .order_by(LoveBondRequest.created_at.desc())
        .all()
    )
    return LoveBondRequestListResponse(
        requests=[LoveBondRequestResponse(**love_bond_service.request_to_dict(item)) for item in requests],
    )


@router.post("/requests/{request_id}/accept", response_model=LoveBondResponse)
async def accept_love_bond_request(
    request_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        bond = love_bond_service.accept_love_bond_request(db, current_user, request_id)
    except PermissionError as error:
        raise HTTPException(status_code=403, detail=str(error)) from error
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error

    await inbox_ws_manager.broadcast_to_users(
        [bond.user_a_id, bond.user_b_id],
        {"event": "love_bond_updated", "bond_id": bond.public_id},
    )
    return LoveBondResponse(**love_bond_service.bond_to_dict(bond, current_user))


@router.post("/requests/{request_id}/reject", response_model=LoveBondRequestResponse)
async def reject_love_bond_request(
    request_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        bond_request = love_bond_service.reject_love_bond_request(db, current_user, request_id)
    except PermissionError as error:
        raise HTTPException(status_code=403, detail=str(error)) from error
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error

    await inbox_ws_manager.broadcast_to_users(
        [bond_request.sender_user_id, bond_request.receiver_user_id],
        {"event": "love_bond_request_updated", "request_id": bond_request.public_id},
    )
    return LoveBondRequestResponse(**love_bond_service.request_to_dict(bond_request))


@router.get("/me", response_model=LoveBondListResponse)
def list_my_love_bonds(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    bonds = love_bond_service.list_active_bonds_for_user(db, current_user)
    return LoveBondListResponse(
        bonds=[LoveBondResponse(**love_bond_service.bond_to_dict(item, current_user)) for item in bonds],
    )


@router.get("/public/{public_user_id}", response_model=LoveBondListResponse)
def list_public_love_bonds(
    public_user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target_user = db.query(User).filter(User.public_user_id == public_user_id, User.is_active.is_(True)).first()
    if target_user is None:
        raise HTTPException(status_code=404, detail="User not found.")

    bonds = love_bond_service.list_active_bonds_for_user(db, target_user)
    return LoveBondListResponse(
        bonds=[LoveBondResponse(**love_bond_service.bond_to_dict(item, target_user)) for item in bonds],
    )
