from datetime import datetime

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.economy import (
    CoinPoolLedger,
    CoinSaleOrder,
    CoinSaleStatus,
    CoinSupplyPool,
    CoinSupplyPoolType,
    EconomyCurrency,
    EconomyDirection,
    EconomyPoolStatus,
    GamePool,
    GamePoolType,
    GameRound,
    GiftTransaction,
    RubyWithdrawRequest,
    UserWallet,
    WalletLedger,
)
from app.models.user import User

RUBY_EARNING_BASIS_POINTS = 3000  # 100 received coins = 30 rubies.


def get_or_create_wallet(db: Session, user_id: int) -> UserWallet:
    wallet = db.query(UserWallet).filter(UserWallet.user_id == user_id).first()
    if wallet:
        return wallet

    wallet = UserWallet(user_id=user_id)
    db.add(wallet)
    db.flush()
    return wallet


def get_pool_for_user(db: Session, user_id: int, pool_type: CoinSupplyPoolType) -> CoinSupplyPool | None:
    return (
        db.query(CoinSupplyPool)
        .filter(CoinSupplyPool.owner_user_id == user_id, CoinSupplyPool.pool_type == pool_type.value)
        .first()
    )


def get_or_create_coin_pool(
    db: Session,
    pool_type: CoinSupplyPoolType,
    owner_user_id: int | None,
) -> CoinSupplyPool:
    pool = (
        db.query(CoinSupplyPool)
        .filter(CoinSupplyPool.pool_type == pool_type.value, CoinSupplyPool.owner_user_id == owner_user_id)
        .first()
    )
    if pool:
        return pool

    pool = CoinSupplyPool(owner_user_id=owner_user_id, pool_type=pool_type.value)
    db.add(pool)
    db.flush()
    return pool


def get_or_create_game_pool(
    db: Session,
    game_key: str,
    pool_type: GamePoolType,
) -> GamePool:
    pool = (
        db.query(GamePool)
        .filter(GamePool.game_key == game_key, GamePool.pool_type == pool_type.value)
        .first()
    )
    if pool:
        return pool

    pool = GamePool(game_key=game_key, pool_type=pool_type.value)
    db.add(pool)
    db.flush()
    return pool


def _assert_active_pool(pool: CoinSupplyPool | GamePool) -> None:
    if pool.status != EconomyPoolStatus.ACTIVE.value:
        raise HTTPException(status_code=400, detail="Pool is not active")


def _credit_wallet(
    db: Session,
    wallet: UserWallet,
    currency: EconomyCurrency,
    amount: int,
    source_type: str,
    source_id: str | None = None,
    created_by_user_id: int | None = None,
    reason: str | None = None,
) -> None:
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")

    if currency == EconomyCurrency.COIN:
        before = wallet.coin_balance
        wallet.coin_balance += amount
        after = wallet.coin_balance
    else:
        before = wallet.ruby_balance
        wallet.ruby_balance += amount
        wallet.lifetime_rubies_earned += amount
        after = wallet.ruby_balance

    db.add(
        WalletLedger(
            user_id=wallet.user_id,
            currency_type=currency.value,
            direction=EconomyDirection.CREDIT.value,
            amount=amount,
            before_balance=before,
            after_balance=after,
            source_type=source_type,
            source_id=source_id,
            created_by_user_id=created_by_user_id,
            reason=reason,
        )
    )


def _debit_wallet(
    db: Session,
    wallet: UserWallet,
    currency: EconomyCurrency,
    amount: int,
    source_type: str,
    source_id: str | None = None,
    created_by_user_id: int | None = None,
    reason: str | None = None,
) -> None:
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")

    if currency == EconomyCurrency.COIN:
        before = wallet.coin_balance
        if before < amount:
            raise HTTPException(status_code=400, detail="Insufficient coin balance")
        wallet.coin_balance -= amount
        wallet.lifetime_coins_spent += amount
        after = wallet.coin_balance
    else:
        before = wallet.ruby_balance
        if before < amount:
            raise HTTPException(status_code=400, detail="Insufficient ruby balance")
        wallet.ruby_balance -= amount
        after = wallet.ruby_balance

    db.add(
        WalletLedger(
            user_id=wallet.user_id,
            currency_type=currency.value,
            direction=EconomyDirection.DEBIT.value,
            amount=amount,
            before_balance=before,
            after_balance=after,
            source_type=source_type,
            source_id=source_id,
            created_by_user_id=created_by_user_id,
            reason=reason,
        )
    )


def _credit_coin_pool(
    db: Session,
    pool: CoinSupplyPool,
    amount: int,
    source_type: str,
    created_by_user_id: int | None,
    reason: str | None,
    source_pool_id: int | None = None,
    target_user_id: int | None = None,
) -> None:
    _assert_active_pool(pool)
    before = pool.balance
    pool.balance += amount
    db.add(
        CoinPoolLedger(
            pool_id=pool.id,
            direction=EconomyDirection.CREDIT.value,
            amount=amount,
            before_balance=before,
            after_balance=pool.balance,
            source_type=source_type,
            source_pool_id=source_pool_id,
            target_user_id=target_user_id,
            created_by_user_id=created_by_user_id,
            reason=reason,
        )
    )


def _debit_coin_pool(
    db: Session,
    pool: CoinSupplyPool,
    amount: int,
    source_type: str,
    created_by_user_id: int | None,
    reason: str | None,
    target_pool_id: int | None = None,
    target_user_id: int | None = None,
) -> None:
    _assert_active_pool(pool)
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")
    if pool.balance < amount:
        raise HTTPException(status_code=400, detail="Insufficient pool balance")
    before = pool.balance
    pool.balance -= amount
    db.add(
        CoinPoolLedger(
            pool_id=pool.id,
            direction=EconomyDirection.DEBIT.value,
            amount=amount,
            before_balance=before,
            after_balance=pool.balance,
            source_type=source_type,
            target_pool_id=target_pool_id,
            target_user_id=target_user_id,
            created_by_user_id=created_by_user_id,
            reason=reason,
        )
    )


def mint_to_pool(
    db: Session,
    actor: User,
    target_pool_type: str,
    amount: int,
    reason: str,
    target_user_id: int | None = None,
) -> CoinSupplyPool:
    pool_type = CoinSupplyPoolType(target_pool_type)
    pool = get_or_create_coin_pool(db, pool_type, target_user_id)
    _credit_coin_pool(
        db=db,
        pool=pool,
        amount=amount,
        source_type="FOUNDER_MINT",
        created_by_user_id=actor.id,
        reason=reason,
        target_user_id=target_user_id,
    )
    db.commit()
    db.refresh(pool)
    return pool


def allocate_pool_to_pool(
    db: Session,
    actor: User,
    source_pool_id: int,
    target_pool_type: str,
    amount: int,
    reason: str,
    target_user_id: int | None,
) -> CoinSupplyPool:
    source = db.query(CoinSupplyPool).filter(CoinSupplyPool.id == source_pool_id).first()
    if not source:
        raise HTTPException(status_code=404, detail="Source pool not found")

    target = get_or_create_coin_pool(db, CoinSupplyPoolType(target_pool_type), target_user_id)
    _debit_coin_pool(db, source, amount, "SUPPLY_ALLOCATION", actor.id, reason, target_pool_id=target.id)
    _credit_coin_pool(db, target, amount, "SUPPLY_ALLOCATION", actor.id, reason, source_pool_id=source.id)
    db.commit()
    db.refresh(target)
    return target


def sell_pool_coins_to_user(
    db: Session,
    seller: User,
    buyer_user_id: int,
    source_pool_id: int,
    coin_amount: int,
    payment_amount: int,
    payment_currency: str,
    proof_url: str | None,
) -> CoinSaleOrder:
    source = db.query(CoinSupplyPool).filter(CoinSupplyPool.id == source_pool_id).first()
    if not source:
        raise HTTPException(status_code=404, detail="Seller pool not found")
    if source.owner_user_id != seller.id:
        raise HTTPException(status_code=403, detail="This pool does not belong to seller")
    if source.pool_type not in {CoinSupplyPoolType.SELLER_SUPPLY_POOL.value, CoinSupplyPoolType.MERCHANT_SUPPLY_POOL.value}:
        raise HTTPException(status_code=400, detail="Only seller or merchant supply pools can sell coins")

    buyer = db.query(User).filter(User.id == buyer_user_id).first()
    if not buyer:
        raise HTTPException(status_code=404, detail="Buyer not found")

    order = CoinSaleOrder(
        seller_user_id=seller.id,
        buyer_user_id=buyer_user_id,
        source_pool_id=source_pool_id,
        coin_amount=coin_amount,
        payment_amount=payment_amount,
        payment_currency=payment_currency,
        proof_url=proof_url,
        payment_status="RECORDED",
        delivery_status=CoinSaleStatus.DELIVERED.value,
        approved_by_user_id=seller.id,
        completed_at=datetime.utcnow(),
    )
    db.add(order)
    db.flush()

    _debit_coin_pool(db, source, coin_amount, "SELLER_COIN_SALE", seller.id, "Coins sold to user", target_user_id=buyer_user_id)
    wallet = get_or_create_wallet(db, buyer_user_id)
    _credit_wallet(db, wallet, EconomyCurrency.COIN, coin_amount, "SELLER_COIN_SALE", str(order.id), seller.id, "Coins delivered from seller pool")
    db.commit()
    db.refresh(order)
    return order


def preview_gift_economy(
    coin_value: int,
    quantity: int,
    room_id: int | None,
    relationship_id: int | None,
    is_relationship_gift: bool,
) -> dict[str, int | str]:
    total = coin_value * quantity
    rubies = total * RUBY_EARNING_BASIS_POINTS // 10000
    platform = total - rubies
    return {
        "total_coin_value": total,
        "receiver_ruby_amount": rubies,
        "platform_share_coin_value": platform,
        "send_exp_amount": total,
        "receive_exp_amount": total,
        "room_exp_amount": total if room_id else 0,
        "love_score_amount": total if relationship_id or is_relationship_gift else 0,
        "rule": "100 received coins = 30 rubies. Coins spend; rubies earn/withdraw. Pool coins are inventory only.",
    }


def convert_rubies_to_coins(db: Session, user: User, ruby_amount: int) -> UserWallet:
    wallet = get_or_create_wallet(db, user.id)
    _debit_wallet(db, wallet, EconomyCurrency.RUBY, ruby_amount, "RUBY_TO_COIN_CONVERSION", created_by_user_id=user.id)
    _credit_wallet(db, wallet, EconomyCurrency.COIN, ruby_amount, "RUBY_TO_COIN_CONVERSION", created_by_user_id=user.id)
    db.commit()
    db.refresh(wallet)
    return wallet


def create_withdraw_request(db: Session, user: User, ruby_amount: int, payout_method: str | None, payout_account_snapshot: str | None) -> RubyWithdrawRequest:
    wallet = get_or_create_wallet(db, user.id)
    if wallet.ruby_balance < ruby_amount:
        raise HTTPException(status_code=400, detail="Insufficient ruby balance")
    wallet.ruby_balance -= ruby_amount
    wallet.pending_withdraw_rubies += ruby_amount
    request = RubyWithdrawRequest(
        user_id=user.id,
        ruby_amount=ruby_amount,
        payout_method=payout_method,
        payout_account_snapshot=payout_account_snapshot,
    )
    db.add(request)
    db.add(
        WalletLedger(
            user_id=user.id,
            currency_type=EconomyCurrency.RUBY.value,
            direction=EconomyDirection.DEBIT.value,
            amount=ruby_amount,
            before_balance=wallet.ruby_balance + ruby_amount,
            after_balance=wallet.ruby_balance,
            source_type="RUBY_WITHDRAW_REQUEST",
            source_id=None,
            created_by_user_id=user.id,
            reason="Rubies locked for withdrawal review",
        )
    )
    db.commit()
    db.refresh(request)
    return request


def create_game_pool(
    db: Session,
    game_key: str,
    pool_type: str,
    opening_balance: int,
    daily_payout_cap: int,
    daily_loss_limit: int,
    max_single_payout: int,
    rtp_target_basis_points: int,
) -> GamePool:
    pool = get_or_create_game_pool(db, game_key, GamePoolType(pool_type))
    pool.daily_payout_cap = daily_payout_cap
    pool.daily_loss_limit = daily_loss_limit
    pool.max_single_payout = max_single_payout
    pool.rtp_target_basis_points = rtp_target_basis_points
    if opening_balance > 0:
        pool.balance += opening_balance
    db.commit()
    db.refresh(pool)
    return pool


def create_game_round(db: Session, game_key: str, entry_fee: int, max_players: int, room_id: int | None) -> GameRound:
    round_obj = GameRound(game_key=game_key, entry_fee=entry_fee, max_players=max_players, room_id=room_id)
    db.add(round_obj)
    db.commit()
    db.refresh(round_obj)
    return round_obj


def dashboard_for_user(db: Session, user: User) -> dict:
    wallet = get_or_create_wallet(db, user.id)
    seller_pool = get_pool_for_user(db, user.id, CoinSupplyPoolType.SELLER_SUPPLY_POOL)
    merchant_pool = get_pool_for_user(db, user.id, CoinSupplyPoolType.MERCHANT_SUPPLY_POOL)
    gaming_pool = db.query(CoinSupplyPool).filter(CoinSupplyPool.owner_user_id == user.id, CoinSupplyPool.pool_type == CoinSupplyPoolType.FRIENDS_GAMING_POOL.value).first()
    return {
        "wallet": wallet,
        "seller_pool": seller_pool,
        "merchant_pool": merchant_pool,
        "gaming_pool": gaming_pool,
    }
