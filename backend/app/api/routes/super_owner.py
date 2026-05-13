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
from app.services.audit_log_service import create_admin_log
from app.services.economy_service import get_or_create_coin_pool, get_or_create_wallet, mint_to_pool
from app.services.role_service import get_primary_role
from app.models.role import RoleName
from app.services.special_permission_service import grant_special_permission

router = APIRouter(prefix="/super-owner", tags=["Super Owner"])


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


@router.get("/coin-pools", response_model=list[SuperOwnerPoolResponse])
def list_coin_pools(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    pools = db.query(CoinSupplyPool).order_by(CoinSupplyPool.id.asc()).all()
    return [_pool_response(pool) for pool in pools]


@router.post("/coins/mint", response_model=SuperOwnerPoolResponse)
def mint_coins(payload: SuperOwnerMintCoinsRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    pool = mint_to_pool(db=db, actor=current_user, target_pool_type=payload.target_pool_type, target_user_id=payload.target_user_id, amount=payload.amount, reason=payload.reason)
    create_admin_log(db=db, actor_user_id=current_user.id, target_user_id=payload.target_user_id, action="SUPER_OWNER_COINS_MINTED", resource_type="coin_supply_pool", resource_id=str(pool.id), reason=payload.reason, metadata_json={"amount": payload.amount, "pool_type": payload.target_pool_type})
    return _pool_response(pool)


@router.post("/coins/send-all", response_model=SuperOwnerActionResponse)
def send_coins_to_all(payload: SuperOwnerSendCoinsAllRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    query = db.query(User)
    if payload.active_only:
        query = query.filter(User.is_active.is_(True), User.is_banned.is_(False))
    users = query.all()
    for user in users:
        wallet = get_or_create_wallet(db, user.id)
        before = wallet.coin_balance
        wallet.coin_balance += payload.coin_amount
        from app.models.economy import WalletLedger, EconomyDirection
        db.add(WalletLedger(user_id=user.id, currency_type=EconomyCurrency.COIN.value, direction=EconomyDirection.CREDIT.value, amount=payload.coin_amount, before_balance=before, after_balance=wallet.coin_balance, source_type="SUPER_OWNER_SEND_ALL", created_by_user_id=current_user.id, reason=payload.reason))
    db.commit()
    create_admin_log(db=db, actor_user_id=current_user.id, action="SUPER_OWNER_COINS_SENT_TO_ALL", resource_type="wallet", reason=payload.reason, metadata_json={"coin_amount": payload.coin_amount, "users_count": len(users), "active_only": payload.active_only})
    return SuperOwnerActionResponse(message=f"Sent {payload.coin_amount} coins to {len(users)} users")


@router.post("/custom-id", response_model=SuperOwnerActionResponse)
def assign_custom_id(payload: SuperOwnerCustomIdRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    target = _target_user(db, payload.target_user_id)
    if payload.display_custom_id is not None:
        existing = db.query(User).filter(User.display_custom_id == payload.display_custom_id, User.id != target.id).first()
        if existing:
            raise HTTPException(status_code=409, detail="Custom ID is already assigned")
    target.display_custom_id = payload.display_custom_id
    db.commit()
    create_admin_log(db=db, actor_user_id=current_user.id, target_user_id=target.id, action="SUPER_OWNER_CUSTOM_ID_ASSIGNED", resource_type="user", resource_id=str(target.id), reason=payload.reason, metadata_json={"display_custom_id": payload.display_custom_id})
    return SuperOwnerActionResponse(message="Custom ID updated", resource_id=str(target.id))


@router.post("/stealth", response_model=SuperOwnerActionResponse)
def set_stealth(payload: SuperOwnerStealthRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    target = _target_user(db, payload.target_user_id)
    permissions = target.interests or []
    marker = "STEALTH_ENABLED"
    if payload.enabled and marker not in permissions:
        permissions.append(marker)
    if not payload.enabled and marker in permissions:
        permissions.remove(marker)
    target.interests = permissions
    db.commit()
    create_admin_log(db=db, actor_user_id=current_user.id, target_user_id=target.id, action="SUPER_OWNER_STEALTH_UPDATED", resource_type="user", resource_id=str(target.id), reason=payload.reason, metadata_json={"enabled": payload.enabled})
    return SuperOwnerActionResponse(message="Stealth updated", resource_id=str(target.id))


@router.get("/special-permissions/options")
def list_special_permission_options(current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    return [{"value": permission.value, "label": permission.value.replace("_", " ").title()} for permission in SpecialPermissionName]


@router.post("/special-permissions/grant", response_model=SuperOwnerActionResponse)
def grant_permission(payload: SuperOwnerSpecialPermissionGrantRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    target = _target_user(db, payload.target_user_id)
    permission = grant_special_permission(db=db, user_id=target.id, permission=payload.permission, granted_by_user_id=current_user.id, reason=payload.reason, expires_at=payload.expires_at)
    create_admin_log(db=db, actor_user_id=current_user.id, target_user_id=target.id, action="SUPER_OWNER_SPECIAL_PERMISSION_GRANTED", resource_type="special_permission", resource_id=str(permission.id), reason=payload.reason, metadata_json={"permission": payload.permission.value})
    return SuperOwnerActionResponse(message="Special permission granted", resource_id=str(permission.id))


@router.get("/special-permissions", response_model=list[dict])
def list_permissions(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    items = db.query(SpecialPermission).order_by(SpecialPermission.id.desc()).limit(200).all()
    return [{"id": item.id, "user_id": item.user_id, "permission": item.permission.value, "is_active": item.is_active, "reason": item.reason, "created_at": item.created_at.isoformat()} for item in items]


@router.post("/vip-adjust", response_model=SuperOwnerVipResponse)
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


@router.post("/levels-adjust", response_model=SuperOwnerWalletResponse)
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


@router.get("/logs", response_model=list[SuperOwnerLogResponse])
def list_logs(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    logs = db.query(AdminLog).order_by(AdminLog.id.desc()).limit(200).all()
    return [SuperOwnerLogResponse(id=log.id, actor_user_id=log.actor_user_id, target_user_id=log.target_user_id, action=log.action, resource_type=log.resource_type, resource_id=log.resource_id, reason=log.reason, created_at=log.created_at) for log in logs]


@router.get("/reviews", response_model=list[SuperOwnerReviewDetailResponse])
def list_reviews(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    logs = db.query(AdminLog).order_by(AdminLog.id.desc()).limit(50).all()
    return [SuperOwnerReviewDetailResponse(id=log.id, kind=log.resource_type or "audit", title=log.action, status="reviewed" if log.action.endswith("_BLOCKED") else "open", reason=log.reason, metadata=log.metadata_json if isinstance(log.metadata_json, dict) else None, created_at=log.created_at) for log in logs]


@router.get("/reviews/{review_id}", response_model=SuperOwnerReviewDetailResponse)
def get_review_detail(review_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_super_owner(current_user)
    log = db.query(AdminLog).filter(AdminLog.id == review_id).first()
    if not log:
        raise HTTPException(status_code=404, detail="Review not found")
    return SuperOwnerReviewDetailResponse(id=log.id, kind=log.resource_type or "audit", title=log.action, status="reviewed" if log.action.endswith("_BLOCKED") else "open", reason=log.reason, metadata=log.metadata_json if isinstance(log.metadata_json, dict) else None, created_at=log.created_at)
