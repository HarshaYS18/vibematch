from __future__ import annotations

from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class EconomyJournalEntry(Base):
    """Append-only balanced accounting leg for an Economy transaction.

    Wallet/pool tables remain operational balance truth. Journal entries are an
    immutable accounting/audit projection and must balance per transaction and
    currency before a transaction can be considered financially reconciled.
    """

    __tablename__ = "economy_journal_entries"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    economy_transaction_id: Mapped[int] = mapped_column(
        ForeignKey("economy_transactions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    transaction_id: Mapped[str] = mapped_column(String(36), nullable=False, index=True)
    business_reference: Mapped[str] = mapped_column(String(200), nullable=False, index=True)
    currency_type: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    account_code: Mapped[str] = mapped_column(String(160), nullable=False, index=True)
    direction: Mapped[str] = mapped_column(String(10), nullable=False, index=True)
    amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    source_type: Mapped[str] = mapped_column(String(80), nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        nullable=False,
        index=True,
    )
