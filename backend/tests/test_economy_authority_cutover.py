from pathlib import Path
import unittest
from unittest.mock import patch

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base
from app.models.economy import EconomyCurrency, UserWallet, WalletLedger
from app.models.economy_journal import EconomyJournalEntry
from app.models.economy_transaction import EconomyTransaction
from app.models.user import User
from app.services import economy_reconciliation_service, economy_transaction_service

ROOT = Path(__file__).resolve().parents[2]


class EconomyAuthorityCutoverTests(unittest.TestCase):
    def _factory(self):
        engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(
            engine,
            tables=[
                User.__table__,
                EconomyTransaction.__table__,
                UserWallet.__table__,
                WalletLedger.__table__,
                EconomyJournalEntry.__table__,
            ],
        )
        return engine, sessionmaker(bind=engine)

    def test_wallet_credit_writes_balanced_journal_in_same_transaction(self):
        engine, factory = self._factory()
        try:
            with factory.begin() as db:
                db.add(User(id=1, public_user_id=6418000001, username="economy-user"))
            with factory() as db:
                tx, cached = economy_transaction_service.begin(
                    db,
                    transaction_id="11111111-1111-1111-1111-111111111111",
                    idempotency_key="stable-idempotency-key",
                    business_reference="test:credit:1",
                    operation_type="wallet.credit",
                    actor_user_id=1,
                    request_payload={"user_id": 1, "amount": 100},
                )
                self.assertIsNone(cached)
                wallet = economy_transaction_service.credit(
                    db,
                    user_id=1,
                    amount=100,
                    currency=EconomyCurrency.COIN.value,
                    source_type="TEST_CREDIT",
                    source_id="test",
                    reason="test",
                    tx=tx,
                    actor_user_id=1,
                )
                with patch.object(
                    economy_transaction_service.event_outbox_service,
                    "enqueue_event",
                ):
                    economy_transaction_service.complete(
                        db,
                        tx=tx,
                        result={"coin_balance": wallet.coin_balance},
                        event_type="economy.test.v1",
                        event_payload={"user_id": 1},
                    )

            with factory() as db:
                legs = db.query(EconomyJournalEntry).order_by(EconomyJournalEntry.id).all()
                self.assertEqual(len(legs), 2)
                self.assertEqual({leg.direction for leg in legs}, {"DEBIT", "CREDIT"})
                self.assertEqual(sum(leg.amount for leg in legs if leg.direction == "DEBIT"), 100)
                self.assertEqual(sum(leg.amount for leg in legs if leg.direction == "CREDIT"), 100)
        finally:
            engine.dispose()

    def test_reconciliation_detects_wallet_materialization_mismatch(self):
        engine, factory = self._factory()
        try:
            with factory.begin() as db:
                db.add(User(id=2, public_user_id=6418000002, username="mismatch-user"))
                db.add(UserWallet(user_id=2, coin_balance=20, ruby_balance=0))
                db.add(
                    WalletLedger(
                        user_id=2,
                        currency_type=EconomyCurrency.COIN.value,
                        direction="CREDIT",
                        amount=10,
                        before_balance=0,
                        after_balance=10,
                        source_type="TEST",
                    )
                )
            with factory() as db:
                report = economy_reconciliation_service.reconcile(db)
                self.assertEqual(report.wallet_mismatches, 1)
                self.assertFalse(report.healthy)
        finally:
            engine.dispose()

    def test_exclusive_ownership_and_reader_role_are_declared(self):
        sql = (ROOT / "deploy/postgres/economy-ownership.sql").read_text(encoding="utf-8")
        for table in (
            "user_wallets",
            "wallet_ledger",
            "coin_supply_pools",
            "game_pool_ledger",
            "economy_transactions",
            "economy_journal_entries",
        ):
            self.assertIn(f"ALTER TABLE {table} OWNER TO funkey_economy_owner", sql)
        self.assertIn("funkey_economy_reader", sql)
        self.assertIn("Never grant funkey_economy_runtime to core-api", sql)

    def test_authority_registry_marks_all_financial_truth_on_economy_service(self):
        registry = (ROOT / "contracts/architecture/authorities.yaml").read_text(encoding="utf-8")
        for state_id in (
            "economy.wallet_ledger",
            "economy.supply_ledger",
            "gifts.catalog",
            "gifts.settlement",
            "games.financial_settlement",
            "missions.reward_claims",
        ):
            marker = f'"id": "{state_id}"'
            start = registry.index(marker)
            block = registry[start:start + 1800]
            self.assertIn('"current_deployable": "economy-service"', block)


if __name__ == "__main__":
    unittest.main()
