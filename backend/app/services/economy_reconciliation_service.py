from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy import case, func
from sqlalchemy.orm import Session

from app.models.economy import (
    CoinPoolLedger,
    CoinSupplyPool,
    EconomyCurrency,
    EconomyDirection,
    GamePool,
    GamePoolLedger,
    UserWallet,
    WalletLedger,
)
from app.models.economy_house_reservation import EconomyHouseReservation
from app.models.economy_journal import EconomyJournalEntry


@dataclass(frozen=True)
class EconomyReconciliationReport:
    wallets_scanned: int
    wallet_mismatches: int
    supply_pools_scanned: int
    supply_pool_mismatches: int
    game_pools_scanned: int
    game_pool_mismatches: int
    reservation_mismatches: int
    journal_transactions_scanned: int
    unbalanced_journal_transactions: int

    @property
    def healthy(self) -> bool:
        return (
            self.wallet_mismatches == 0
            and self.supply_pool_mismatches == 0
            and self.game_pool_mismatches == 0
            and self.reservation_mismatches == 0
            and self.unbalanced_journal_transactions == 0
        )


def _latest_wallet_ledger_rows(
    db: Session,
    *,
    user_ids: list[int],
    currency: str,
) -> dict[int, WalletLedger]:
    if not user_ids:
        return {}
    latest_ids = (
        db.query(
            WalletLedger.user_id.label("user_id"),
            func.max(WalletLedger.id).label("ledger_id"),
        )
        .filter(
            WalletLedger.user_id.in_(user_ids),
            WalletLedger.currency_type == currency,
        )
        .group_by(WalletLedger.user_id)
        .subquery()
    )
    rows = (
        db.query(WalletLedger)
        .join(latest_ids, WalletLedger.id == latest_ids.c.ledger_id)
        .all()
    )
    return {int(row.user_id): row for row in rows}


def _latest_pool_ledger_rows(
    db: Session,
    *,
    ledger_model,
    pool_ids: list[int],
) -> dict[int, object]:
    if not pool_ids:
        return {}
    latest_ids = (
        db.query(
            ledger_model.pool_id.label("pool_id"),
            func.max(ledger_model.id).label("ledger_id"),
        )
        .filter(ledger_model.pool_id.in_(pool_ids))
        .group_by(ledger_model.pool_id)
        .subquery()
    )
    rows = (
        db.query(ledger_model)
        .join(latest_ids, ledger_model.id == latest_ids.c.ledger_id)
        .all()
    )
    return {int(row.pool_id): row for row in rows}


def reconcile(
    db: Session,
    *,
    wallet_limit: int = 500,
    pool_limit: int = 500,
    journal_transaction_limit: int = 1000,
) -> EconomyReconciliationReport:
    """Read-only verification of all materialized Economy balances.

    Reconciliation never writes repairs. Any mismatch is an incident that must
    be resolved from authoritative transaction/ledger/journal evidence.
    """

    wallets = (
        db.query(UserWallet)
        .order_by(UserWallet.id.asc())
        .limit(max(1, int(wallet_limit)))
        .all()
    )
    user_ids = [int(wallet.user_id) for wallet in wallets]
    latest_coin = _latest_wallet_ledger_rows(
        db,
        user_ids=user_ids,
        currency=EconomyCurrency.COIN.value,
    )
    latest_ruby = _latest_wallet_ledger_rows(
        db,
        user_ids=user_ids,
        currency=EconomyCurrency.RUBY.value,
    )

    wallet_mismatches = 0
    for wallet in wallets:
        coin_row = latest_coin.get(int(wallet.user_id))
        ruby_row = latest_ruby.get(int(wallet.user_id))
        if coin_row is not None and int(coin_row.after_balance) != int(wallet.coin_balance or 0):
            wallet_mismatches += 1
        if ruby_row is not None and int(ruby_row.after_balance) != int(wallet.ruby_balance or 0):
            wallet_mismatches += 1

    supply_pools = (
        db.query(CoinSupplyPool)
        .order_by(CoinSupplyPool.id.asc())
        .limit(max(1, int(pool_limit)))
        .all()
    )
    latest_supply = _latest_pool_ledger_rows(
        db,
        ledger_model=CoinPoolLedger,
        pool_ids=[int(pool.id) for pool in supply_pools],
    )
    supply_pool_mismatches = sum(
        1
        for pool in supply_pools
        if latest_supply.get(int(pool.id)) is not None
        and int(latest_supply[int(pool.id)].after_balance) != int(pool.balance or 0)
    )

    game_pools = (
        db.query(GamePool)
        .order_by(GamePool.id.asc())
        .limit(max(1, int(pool_limit)))
        .all()
    )
    game_pool_ids = [int(pool.id) for pool in game_pools]
    latest_game = _latest_pool_ledger_rows(
        db,
        ledger_model=GamePoolLedger,
        pool_ids=game_pool_ids,
    )
    game_pool_mismatches = sum(
        1
        for pool in game_pools
        if latest_game.get(int(pool.id)) is not None
        and int(latest_game[int(pool.id)].after_balance) != int(pool.balance or 0)
    )

    reservation_totals = dict(
        db.query(
            EconomyHouseReservation.pool_id,
            func.coalesce(func.sum(EconomyHouseReservation.amount), 0),
        )
        .filter(
            EconomyHouseReservation.pool_id.in_(game_pool_ids or [-1]),
            EconomyHouseReservation.status == "ACTIVE",
        )
        .group_by(EconomyHouseReservation.pool_id)
        .all()
    )
    reservation_mismatches = sum(
        1
        for pool in game_pools
        if int(pool.reserved_balance or 0)
        != int(reservation_totals.get(int(pool.id), 0) or 0)
    )

    debit_total = func.sum(
        case(
            (
                EconomyJournalEntry.direction == EconomyDirection.DEBIT.value,
                EconomyJournalEntry.amount,
            ),
            else_=0,
        )
    )
    credit_total = func.sum(
        case(
            (
                EconomyJournalEntry.direction == EconomyDirection.CREDIT.value,
                EconomyJournalEntry.amount,
            ),
            else_=0,
        )
    )
    journal_rows = (
        db.query(
            EconomyJournalEntry.transaction_id,
            EconomyJournalEntry.currency_type,
            debit_total.label("debits"),
            credit_total.label("credits"),
        )
        .group_by(
            EconomyJournalEntry.transaction_id,
            EconomyJournalEntry.currency_type,
        )
        .order_by(func.max(EconomyJournalEntry.id).desc())
        .limit(max(1, int(journal_transaction_limit)))
        .all()
    )
    unbalanced = sum(
        1
        for _transaction_id, _currency, debits, credits in journal_rows
        if int(debits or 0) != int(credits or 0)
    )

    return EconomyReconciliationReport(
        wallets_scanned=len(wallets),
        wallet_mismatches=wallet_mismatches,
        supply_pools_scanned=len(supply_pools),
        supply_pool_mismatches=supply_pool_mismatches,
        game_pools_scanned=len(game_pools),
        game_pool_mismatches=game_pool_mismatches,
        reservation_mismatches=reservation_mismatches,
        journal_transactions_scanned=len(journal_rows),
        unbalanced_journal_transactions=unbalanced,
    )
