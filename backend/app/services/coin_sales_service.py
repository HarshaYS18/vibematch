from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.economy import CoinSaleOrder, CoinSaleStatus, CoinSupplyPool, CoinSupplyPoolType, EconomyCurrency, EconomyDirection, WalletLedger
from app.models.role import RoleName
from app.models.user import User
from app.services import economy_service, role_service

SELLER_ROLES = {
    RoleName.FOUNDER_OWNER,
    RoleName.OWNER,
    RoleName.MERCHANT,
    RoleName.COIN_SELLER,
    RoleName.RESELLER,
}

ROLE_POOL_TYPES = {
    RoleName.FOUNDER_OWNER: {
        CoinSupplyPoolType.FOUNDER_MINT_POOL.value,
        CoinSupplyPoolType.OWNER_SUPPLY_POOL.value,
        CoinSupplyPoolType.MERCHANT_SUPPLY_POOL.value,
        CoinSupplyPoolType.SELLER_SUPPLY_POOL.value,
        CoinSupplyPoolType.FRIENDS_GAMING_POOL.value,
    },
    RoleName.OWNER: {
        CoinSupplyPoolType.OWNER_SUPPLY_POOL.value,
        CoinSupplyPoolType.MERCHANT_SUPPLY_POOL.value,
        CoinSupplyPoolType.SELLER_SUPPLY_POOL.value,
        CoinSupplyPoolType.FRIENDS_GAMING_POOL.value,
    },
    RoleName.MERCHANT: {CoinSupplyPoolType.MERCHANT_SUPPLY_POOL.value},
    RoleName.COIN_SELLER: {CoinSupplyPoolType.SELLER_SUPPLY_POOL.value},
    RoleName.RESELLER: {CoinSupplyPoolType.SELLER_SUPPLY_POOL.value},
}

SELLABLE_POOL_TYPES = {
    CoinSupplyPoolType.FOUNDER_MINT_POOL.value,
    CoinSupplyPoolType.OWNER_SUPPLY_POOL.value,
    CoinSupplyPoolType.MERCHANT_SUPPLY_POOL.value,
    CoinSupplyPoolType.SELLER_SUPPLY_POOL.value,
    CoinSupplyPoolType.FRIENDS_GAMING_POOL.value,
}


def _primary_role(user: User) -> RoleName:
    return role_service.get_primary_role(user)


def assert_can_sell(actor: User) -> RoleName:
    role = _primary_role(actor)
    if role not in SELLER_ROLES:
        raise HTTPException(status_code=403, detail="This account is not allowed to sell/send coins to users.")
    return role


def assert_can_use_pool(actor: User, pool: CoinSupplyPool) -> RoleName:
    role = assert_can_sell(actor)
    if role in {RoleName.FOUNDER_OWNER, RoleName.OWNER}:
        if pool.pool_type not in SELLABLE_POOL_TYPES:
            raise HTTPException(status_code=400, detail="This pool type cannot be sold to users.")
        return role
    if pool.owner_user_id != actor.id:
        raise HTTPException(status_code=403, detail="This supply pool does not belong to this seller account.")
    if pool.pool_type not in ROLE_POOL_TYPES.get(role, set()):
        raise HTTPException(status_code=403, detail="This role cannot sell from this pool type.")
    return role


def default_pool_type_for_role(role: RoleName) -> str:
    if role == RoleName.FOUNDER_OWNER:
        return CoinSupplyPoolType.FOUNDER_MINT_POOL.value
    if role == RoleName.OWNER:
        return CoinSupplyPoolType.OWNER_SUPPLY_POOL.value
    if role == RoleName.MERCHANT:
        return CoinSupplyPoolType.MERCHANT_SUPPLY_POOL.value
    if role in {RoleName.COIN_SELLER, RoleName.RESELLER}:
        return CoinSupplyPoolType.SELLER_SUPPLY_POOL.value
    raise HTTPException(status_code=403, detail="This role has no default coin sale pool.")


def get_seller_pools(db: Session, actor: User) -> list[CoinSupplyPool]:
    role = assert_can_sell(actor)
    query = db.query(CoinSupplyPool)
    if role in {RoleName.FOUNDER_OWNER, RoleName.OWNER}:
        return query.filter(CoinSupplyPool.pool_type.in_(list(SELLABLE_POOL_TYPES))).order_by(CoinSupplyPool.id.asc()).all()
    allowed = list(ROLE_POOL_TYPES.get(role, set()))
    return query.filter(CoinSupplyPool.owner_user_id == actor.id, CoinSupplyPool.pool_type.in_(allowed)).order_by(CoinSupplyPool.id.asc()).all()


def grant_supply_to_seller(db: Session, actor: User, target_public_user_id: int, pool_type: str, amount: int, reason: str) -> CoinSupplyPool:
    if not role_service.is_owner_or_above(actor):
        raise HTTPException(status_code=403, detail="Only Owner or Super Owner can grant seller supply.")
    target = db.query(User).filter(User.public_user_id == target_public_user_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="Target user not found")
    if pool_type not in SELLABLE_POOL_TYPES:
        raise HTTPException(status_code=400, detail="Invalid seller supply pool type")
    pool = economy_service.get_or_create_coin_pool(db, CoinSupplyPoolType(pool_type), target.id)
    before = pool.balance
    pool.balance += amount
    from app.models.economy import CoinPoolLedger
    db.add(CoinPoolLedger(
        pool_id=pool.id,
        direction=EconomyDirection.CREDIT.value,
        amount=amount,
        before_balance=before,
        after_balance=pool.balance,
        source_type="SELLER_SUPPLY_GRANT",
        target_user_id=target.id,
        created_by_user_id=actor.id,
        reason=reason,
    ))
    db.commit()
    db.refresh(pool)
    return pool


def _find_pool_for_sale(db: Session, actor: User, source_pool_id: int | None) -> CoinSupplyPool:
    role = assert_can_sell(actor)
    if source_pool_id is not None:
        pool = db.query(CoinSupplyPool).filter(CoinSupplyPool.id == source_pool_id).first()
        if not pool:
            raise HTTPException(status_code=404, detail="Source pool not found")
        assert_can_use_pool(actor, pool)
        return pool
    pool_type = default_pool_type_for_role(role)
    owner_user_id = None if role in {RoleName.FOUNDER_OWNER, RoleName.OWNER} and pool_type == CoinSupplyPoolType.FOUNDER_MINT_POOL.value else actor.id
    pool = economy_service.get_or_create_coin_pool(db, CoinSupplyPoolType(pool_type), owner_user_id)
    return pool


def sell_to_user(db: Session, seller: User, target_public_user_id: int, coin_amount: int, payment_amount: int, payment_currency: str, proof_url: str | None, source_pool_id: int | None, reason: str) -> dict:
    buyer = db.query(User).filter(User.public_user_id == target_public_user_id).first()
    if not buyer:
        raise HTTPException(status_code=404, detail="Buyer user not found")
    if buyer.id == seller.id:
        raise HTTPException(status_code=400, detail="Cannot sell coins to yourself")
    source = _find_pool_for_sale(db, seller, source_pool_id)
    assert_can_use_pool(seller, source)
    if source.balance < coin_amount:
        raise HTTPException(status_code=400, detail="Insufficient seller supply balance")

    order = CoinSaleOrder(
        seller_user_id=seller.id,
        buyer_user_id=buyer.id,
        source_pool_id=source.id,
        coin_amount=coin_amount,
        payment_amount=payment_amount,
        payment_currency=payment_currency,
        proof_url=proof_url,
        payment_status="RECORDED",
        delivery_status=CoinSaleStatus.DELIVERED.value,
        approved_by_user_id=seller.id,
    )
    db.add(order)
    db.flush()

    before_pool = source.balance
    source.balance -= coin_amount
    from app.models.economy import CoinPoolLedger
    db.add(CoinPoolLedger(
        pool_id=source.id,
        direction=EconomyDirection.DEBIT.value,
        amount=coin_amount,
        before_balance=before_pool,
        after_balance=source.balance,
        source_type="ROLE_COIN_SALE",
        target_user_id=buyer.id,
        created_by_user_id=seller.id,
        reason=reason,
    ))

    wallet = economy_service.get_or_create_wallet(db, buyer.id)
    before_wallet = wallet.coin_balance
    wallet.coin_balance += coin_amount
    db.add(WalletLedger(
        user_id=buyer.id,
        currency_type=EconomyCurrency.COIN.value,
        direction=EconomyDirection.CREDIT.value,
        amount=coin_amount,
        before_balance=before_wallet,
        after_balance=wallet.coin_balance,
        source_type="ROLE_COIN_SALE",
        source_id=str(order.id),
        created_by_user_id=seller.id,
        reason=reason,
    ))
    db.commit()
    db.refresh(order)
    db.refresh(source)
    db.refresh(wallet)
    return {
        "order_id": order.id,
        "seller_user_id": seller.id,
        "buyer_user_id": buyer.id,
        "buyer_public_user_id": buyer.public_user_id,
        "source_pool_id": source.id,
        "coin_amount": coin_amount,
        "buyer_wallet_coin_balance": wallet.coin_balance,
        "seller_pool_balance": source.balance,
        "delivery_status": order.delivery_status,
        "note": "Coins delivered to buyer wallet. Seller supply pool coins remain separate from personal wallet coins.",
    }
