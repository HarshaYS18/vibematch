from uuid import uuid4

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.admin_log import AdminLog
from app.models.economy import CoinSupplyPool, CoinSupplyPoolType, EconomyCurrency
from app.models.special_permission import SpecialPermission, SpecialPermissionName
from app.models.user import User
from app.models.vip_status import UserVipStatus
from app.schemas.super_owner import (
    SuperOwnerActionResponse,
    SuperOwnerCustomIdRequest,
    SuperOwnerInboxLockCodeRequest,
    SuperOwnerInboxLockCodeResponse,
    SuperOwnerLevelAdjustmentRequest,
    SuperOwnerLogResponse,
    SuperOwnerMintCoinsRequest,
    SuperOwnerPoolResponse,
    SuperOwnerReviewDetailResponse,
    SuperOwnerSendCoinsAllRequest,
    SuperOwnerSpecialPermissionGrantRequest,
    SuperOwnerStealthRequest,
    SuperOwnerVipAdjustmentRequest,
    SuperOwnerVipResponse,
    SuperOwnerWalletResponse,
)
from app.services import economy_service_client, inbox_lock_service, profile_social_service_client
from app.services.audit_log_service import create_admin_log
from app.services.economy_service import get_or_create_coin_pool, get_or_create_wallet
from app.services.role_service import get_primary_role
from app.models.role import RoleName
from app.services.special_permission_service import grant_special_permission

router = APIRouter(tags=["Super Owner"])


def require_super_owner(user: User) -> None:
    if get_primary_role(user) != RoleName.FOUNDER_OWNER:
        raise HTTPException(status_code=403, detail="Super Owner access required")


def _pool_response(pool: CoinSupplyPool) -> SuperOwnerPoolResponse:
    return SuperOwnerPoolResponse(id=pool.id, owner_user_id=pool.owner_user_id, pool_type=pool.pool_type, balance=pool.balance, reserved_balance=pool.reserved_balance, status=pool.status)


def _wallet_response(user_id: int, db: Session) -> SuperOwnerWalletResponse:
    wallet = get_or_create_wallet(db, user_id)
    return SuperOwnerWalletResponse(user_id=user_id, coin_balance=wallet.coin_balance, ruby_balance=wallet.ruby_balance, lifetime_coins_spent=wallet.lifetime_coins_spent, lifetime_coins_received_as_gifts=wallet.lifetime_coins_received_as_gifts, lifetime_rubies_earned=wallet.lifetime_rubies_earned)


def _target_user(db: Session, target_user_id: int) -> User:
    user = db.query(User).filter(User.id == target_user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Target user not found")
    return user


def _target_user_by_identifier(db: Session, value: str) -> User:
    clean = (value or "").strip()
    if not clean:
        raise HTTPException(status_code=400, detail="User identifier is required")
    query = db.query(User)
    if clean.isdigit():
        numeric = int(clean)
        user = query.filter((User.id == numeric) | (User.public_user_id == numeric) | (User.display_custom_id == numeric)).first()
        if user:
            return user
    user = query.filter((User.username == clean) | (User.email == clean)).first()
    if not user:
        raise HTTPException(status_code=404, detail="Target user not found")
    return user


@router.get("/admin/economy/coin-pools", response_model=list[SuperOwnerPoolResponse])
def list_coin_pools(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    pools = db.query(CoinSupplyPool).order_by(CoinSupplyPool.id.asc()).all()
    return [_pool_response(pool) for pool in pools]


@router.post("/admin/economy/coins/mint", response_model=SuperOwnerPoolResponse)
def mint_coins(payload: SuperOwnerMintCoinsRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    request_id = (payload.request_id or str(uuid4())).strip()
    try:
        result = economy_service_client.mint_supply(
            request_id=request_id,
            actor_user_id=current_user.id,
            target_pool_type=payload.target_pool_type,
            target_user_id=payload.target_user_id,
            amount=payload.amount,
            reason=payload.reason,
        )
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        target_user_id=payload.target_user_id,
        action="SUPER_OWNER_COINS_MINTED",
        resource_type="coin_supply_pool",
        resource_id=str(result["id"]),
        reason=payload.reason,
        metadata_json={
            "amount": payload.amount,
            "pool_type": payload.target_pool_type,
            "economy_transaction_id": result.get("transaction_id"),
        },
    )
    return SuperOwnerPoolResponse(
        id=int(result["id"]),
        pool_type=str(result["pool_type"]),
        owner_user_id=result.get("owner_user_id"),
        balance=int(result["balance"]),
        reserved_balance=int(result.get("reserved_balance") or 0),
        status=str(result["status"]),
    )


@router.post("/admin/economy/coins/send-all", response_model=SuperOwnerActionResponse)
def send_coins_to_all(
    payload: SuperOwnerSendCoinsAllRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_super_owner(current_user)
    request_id = (payload.request_id or str(uuid4())).strip()
    try:
        result = economy_service_client.queue_bulk_grant(
            request_id=request_id,
            actor_user_id=current_user.id,
            coin_amount=payload.coin_amount,
            active_only=payload.active_only,
            reason=payload.reason,
        )
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(
            status_code=exc.status_code,
            detail=exc.detail,
        ) from exc

    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        action="SUPER_OWNER_COINS_SEND_ALL_QUEUED",
        resource_type="economy_bulk_grant",
        resource_id=str(result["grant_id"]),
        reason=payload.reason,
        metadata_json={
            "coin_amount": payload.coin_amount,
            "eligible_count": int(result["eligible_count"]),
            "active_only": payload.active_only,
            "grant_status": result["status"],
        },
    )
    return SuperOwnerActionResponse(
        message=(
            f"Queued {payload.coin_amount} coins for "
            f"{int(result['eligible_count'])} users"
        )
    )


@router.post("/admin/users/custom-id", response_model=SuperOwnerActionResponse)
def assign_custom_id(payload: SuperOwnerCustomIdRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    target = _target_user(db, payload.target_user_id)
    if payload.display_custom_id is not None:
        existing = db.query(User).filter(User.display_custom_id == payload.display_custom_id, User.id != target.id).first()
        if existing:
            raise HTTPException(status_code=409, detail="Custom ID is already assigned")
    try:
        profile_social_service_client.assign_custom_id(
            user_id=target.id,
            display_custom_id=payload.display_custom_id,
        )
    except profile_social_service_client.ProfileSocialServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except profile_social_service_client.ProfileSocialServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    create_admin_log(db=db, actor_user_id=current_user.id, target_user_id=target.id, action="SUPER_OWNER_CUSTOM_ID_ASSIGNED", resource_type="user", resource_id=str(target.id), reason=payload.reason, metadata_json={"display_custom_id": payload.display_custom_id})
    return SuperOwnerActionResponse(message="Custom ID updated", resource_id=str(target.id))


@router.post("/admin/users/inbox-lock/code", response_model=SuperOwnerInboxLockCodeResponse)
def set_inbox_lock_code(payload: SuperOwnerInboxLockCodeRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    target = _target_user_by_identifier(db, payload.user_identifier)
    setting = inbox_lock_service.owner_reset_lock(db, target, payload.lock_code)
    create_admin_log(db=db, actor_user_id=current_user.id, target_user_id=target.id, action="SUPER_OWNER_INBOX_LOCK_CODE_SET", resource_type="inbox_lock_setting", resource_id=str(setting.id), reason=payload.reason, metadata_json={"mode": payload.mode, "public_user_id": target.public_user_id, "display_custom_id": target.display_custom_id})
    return SuperOwnerInboxLockCodeResponse(message="Inbox lock setup/reset code updated", user_id=target.id, public_user_id=target.public_user_id, display_custom_id=target.display_custom_id, username=target.username, display_name=target.display_name, lock_enabled=setting.is_enabled, recovery_requested=setting.recovery_requested, mode=payload.mode)


@router.post("/admin/users/stealth", response_model=SuperOwnerActionResponse)
def set_stealth(payload: SuperOwnerStealthRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    target = _target_user(db, payload.target_user_id)
    try:
        profile_social_service_client.set_stealth(
            user_id=target.id,
            enabled=payload.enabled,
            actor_user_id=current_user.id,
            reason=payload.reason,
        )
    except profile_social_service_client.ProfileSocialServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except profile_social_service_client.ProfileSocialServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    create_admin_log(db=db, actor_user_id=current_user.id, target_user_id=target.id, action="SUPER_OWNER_STEALTH_UPDATED", resource_type="user_stealth_state", resource_id=str(target.id), reason=payload.reason, metadata_json={"enabled": payload.enabled})
    return SuperOwnerActionResponse(message="Stealth updated", resource_id=str(target.id))


@router.get("/admin/users/special-permissions/options")
def list_special_permission_options(current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    return [{"value": permission.value, "label": permission.value.replace("_", " ").title()} for permission in SpecialPermissionName]


@router.post("/admin/users/vip-adjust", response_model=SuperOwnerVipResponse)
def adjust_vip(payload: SuperOwnerVipAdjustmentRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    target = _target_user(db, payload.target_user_id)
    status = db.query(UserVipStatus).filter(UserVipStatus.user_id == target.id).first()
    if status is None:
        status = UserVipStatus(user_id=target.id)
        db.add(status)
        db.flush()
    status.vip_level = payload.vip_level
    status.svip_level = payload.svip_level
    status.vip_is_active = payload.vip_is_active
    status.svip_is_active = payload.svip_is_active
    status.svip_expires_at = payload.svip_expires_at
    status.updated_by_user_id = current_user.id
    status.update_reason = payload.reason
    db.commit()
    db.refresh(status)
    create_admin_log(db=db, actor_user_id=current_user.id, target_user_id=target.id, action="SUPER_OWNER_VIP_ADJUSTED", resource_type="user_vip_status", resource_id=str(status.id), reason=payload.reason, metadata_json={"vip_level": payload.vip_level, "svip_level": payload.svip_level})
    return SuperOwnerVipResponse(user_id=target.id, vip_level=status.vip_level, svip_level=status.svip_level, vip_is_active=status.vip_is_active, svip_is_active=status.svip_is_active, svip_expires_at=status.svip_expires_at)


@router.post("/admin/users/levels-adjust", response_model=SuperOwnerWalletResponse)
def adjust_levels(payload: SuperOwnerLevelAdjustmentRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    target = _target_user(db, payload.target_user_id)
    wallet = get_or_create_wallet(db, target.id)
    if payload.send_exp_total is not None:
        wallet.lifetime_coins_spent = payload.send_exp_total
    if payload.receive_exp_total is not None:
        wallet.lifetime_coins_received_as_gifts = payload.receive_exp_total
    if payload.ruby_total is not None:
        wallet.lifetime_rubies_earned = payload.ruby_total
        wallet.ruby_balance = payload.ruby_total
    db.commit()
    create_admin_log(db=db, actor_user_id=current_user.id, target_user_id=target.id, action="SUPER_OWNER_LEVELS_ADJUSTED", resource_type="user_wallet", resource_id=str(wallet.id), reason=payload.reason, metadata_json={"send_exp_total": payload.send_exp_total, "receive_exp_total": payload.receive_exp_total, "ruby_total": payload.ruby_total})
    return _wallet_response(target.id, db)


@router.get("/admin/moderation/owner-logs", response_model=list[SuperOwnerLogResponse])
def list_logs(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    logs = db.query(AdminLog).order_by(AdminLog.id.desc()).limit(200).all()
    return [SuperOwnerLogResponse(id=log.id, actor_user_id=log.actor_user_id, target_user_id=log.target_user_id, action=log.action, resource_type=log.resource_type, resource_id=log.resource_id, reason=log.reason, created_at=log.created_at) for log in logs]


@router.get("/admin/moderation/reviews", response_model=list[SuperOwnerReviewDetailResponse])
def list_reviews(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    logs = db.query(AdminLog).order_by(AdminLog.id.desc()).limit(50).all()
    return [SuperOwnerReviewDetailResponse(id=log.id, kind=log.resource_type or "audit", title=log.action, status="reviewed" if log.action.endswith("_BLOCKED") else "open", reason=log.reason, metadata=log.metadata_json if isinstance(log.metadata_json, dict) else None, created_at=log.created_at) for log in logs]


@router.get("/admin/moderation/reviews/{review_id}", response_model=SuperOwnerReviewDetailResponse)
def get_review_detail(review_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    log = db.query(AdminLog).filter(AdminLog.id == review_id).first()
    if not log:
        raise HTTPException(status_code=404, detail="Review not found")
    return SuperOwnerReviewDetailResponse(id=log.id, kind=log.resource_type or "audit", title=log.action, status="reviewed" if log.action.endswith("_BLOCKED") else "open", reason=log.reason, metadata=log.metadata_json if isinstance(log.metadata_json, dict) else None, created_at=log.created_at)