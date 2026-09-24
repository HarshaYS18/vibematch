from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy import case, func
from sqlalchemy.orm import Session

from app.models.economy import (
    EconomyCurrency,
    EconomyDirection,
    UserWallet,
    WalletLedger,
)
from app.models.economy_journal import EconomyJournalEntry


@dataclass(frozen=True)
class EconomyReconciliationReport:
    wallets_scanned: int
    wallet_mismatches: int
    journal_transactions_scanned: int
    unbalanced_journal_transactions: int

    @property
    def healthy(self) -> bool:
        return (
            self.wallet_mismatches == 0
            and self.unbalanced_journal_transactions == 0
        )


def _latest_ledger_rows(
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


def reconcile(
    db: Session,
    *,
    wallet_limit: int = 500,
    journal_transaction_limit: int = 1000,
) -> EconomyReconciliationReport:
    """Verify wallet materializations and balanced journal invariants.

    This function is read-only. It never repairs balances automatically; a
    mismatch is an incident that must be reconciled against durable ledger and
    transaction evidence.
    """

    wallets = (
        db.query(UserWallet)
        .order_by(UserWallet.id.asc())
        .limit(max(1, int(wallet_limit)))
        .all()
    )
    user_ids = [int(wallet.user_id) for wallet in wallets]
    latest_coin = _latest_ledger_rows(
        db,
        user_ids=user_ids,
        currency=EconomyCurrency.COIN.value,
    )
    latest_ruby = _latest_ledger_rows(
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

    debit_total = func.sum(
        case(
            (EconomyJournalEntry.direction == EconomyDirection.DEBIT.value, EconomyJournalEntry.amount),
            else_=0,
        )
    )
    credit_total = func.sum(
        case(
            (EconomyJournalEntry.direction == EconomyDirection.CREDIT.value, EconomyJournalEntry.amount),
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
        journal_transactions_scanned=len(journal_rows),
        unbalanced_journal_transactions=unbalanced,
    )
