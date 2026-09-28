from __future__ import annotations

from datetime import datetime, timedelta
import hashlib
import json
from typing import Any

from fastapi import HTTPException
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.models.economy import EconomyCurrency, EconomyDirection, UserWallet, WalletLedger
from app.models.economy_bulk_grant import EconomyBulkGrant, EconomyBulkGrantRecipient
from app.models.user import User
from app.services import economy_service_client, economy_transaction_service, event_outbox_service


RUNNABLE = ("PENDING", "RUNNING", "RETRY")


def _hash(payload: dict[str, Any]) -> str:
    return hashlib.sha256(
        json.dumps(
            payload,
            sort_keys=True,
            separators=(",", ":"),
            default=str,
        ).encode("utf-8")
    ).hexdigest()


def create_job(
    db: Session,
    *,
    grant_id: str,
    idempotency_key: str,
    actor_user_id: int,
    coin_amount: int,
    active_only: bool,
    reason: str,
) -> tuple[EconomyBulkGrant, bool]:
    if int(coin_amount or 0) <= 0:
        raise HTTPException(status_code=400, detail="coin_amount must be positive")
    request_payload = {
        "actor_user_id": actor_user_id,
        "coin_amount": int(coin_amount),
        "active_only": bool(active_only),
        "reason": reason,
    }
    request_hash = _hash(request_payload)
    existing = (
        db.query(EconomyBulkGrant)
        .filter(EconomyBulkGrant.idempotency_key == idempotency_key)
        .with_for_update()
        .first()
    )
    if existing is not None:
        if existing.request_hash != request_hash or existing.grant_id != grant_id:
            raise HTTPException(
                status_code=409,
                detail="Bulk grant idempotency key reused with different request",
            )
        return existing, False

    max_user_id = int(db.query(func.coalesce(func.max(User.id), 0)).scalar() or 0)
    eligible = db.query(func.count(User.id)).filter(User.id <= max_user_id)
    if active_only:
        eligible = eligible.filter(
            User.is_active.is_(True),
            User.is_banned.is_(False),
        )
    eligible_count = int(eligible.scalar() or 0)

    job = EconomyBulkGrant(
        grant_id=grant_id,
        idempotency_key=idempotency_key,
        request_hash=request_hash,
        actor_user_id=actor_user_id,
        coin_amount=int(coin_amount),
        active_only=bool(active_only),
        reason=reason,
        status="PENDING",
        max_user_id=max_user_id,
        last_user_id=0,
        eligible_count=eligible_count,
        processed_count=0,
        failure_count=0,
        next_attempt_at=datetime.utcnow(),
    )
    db.add(job)
    db.flush()
    return job, True


def claim_next_job(
    db: Session,
    *,
    worker_id: str,
    lease_seconds: int,
) -> int | None:
    now = datetime.utcnow()
    job = (
        db.query(EconomyBulkGrant)
        .filter(
            EconomyBulkGrant.status.in_(RUNNABLE),
            or_(
                EconomyBulkGrant.lease_until.is_(None),
                EconomyBulkGrant.lease_until < now,
            ),
            or_(
                EconomyBulkGrant.next_attempt_at.is_(None),
                EconomyBulkGrant.next_attempt_at <= now,
            ),
        )
        .order_by(EconomyBulkGrant.id.asc())
        .with_for_update(skip_locked=True)
        .first()
    )
    if job is None:
        db.rollback()
        return None
    job.status = "RUNNING"
    job.lease_owner = worker_id
    job.lease_until = now + timedelta(seconds=max(int(lease_seconds), 30))
    job.next_attempt_at = None
    db.add(job)
    db.commit()
    return job.id


def _wallets_for_update(db: Session, user_ids: list[int]) -> dict[int, UserWallet]:
    wallets = (
        db.query(UserWallet)
        .filter(UserWallet.user_id.in_(user_ids))
        .with_for_update()
        .all()
    )
    by_user = {int(wallet.user_id): wallet for wallet in wallets}
    missing = [user_id for user_id in user_ids if user_id not in by_user]
    if missing:
        created = [UserWallet(user_id=user_id) for user_id in missing]
        db.add_all(created)
        db.flush()
        by_user.update({int(wallet.user_id): wallet for wallet in created})
    return by_user


def process_claimed_batch(
    db: Session,
    *,
    job_id: int,
    worker_id: str,
    batch_size: int,
) -> dict[str, Any]:
    job = (
        db.query(EconomyBulkGrant)
        .filter(EconomyBulkGrant.id == job_id)
        .with_for_update()
        .first()
    )
    if job is None:
        raise RuntimeError("Bulk grant job disappeared")
    if job.status == "COMPLETED":
        db.rollback()
        return {"status": "COMPLETED", "processed": 0}
    if job.lease_owner != worker_id:
        raise RuntimeError("Bulk grant lease lost")

    user_query = db.query(User.id).filter(
        User.id > job.last_user_id,
        User.id <= job.max_user_id,
    )
    if job.active_only:
        user_query = user_query.filter(
            User.is_active.is_(True),
            User.is_banned.is_(False),
        )
    user_ids = [
        int(row[0])
        for row in user_query.order_by(User.id.asc()).limit(max(int(batch_size), 1)).all()
    ]

    if not user_ids:
        job.status = "COMPLETED"
        job.completed_at = datetime.utcnow()
        job.lease_owner = None
        job.lease_until = None
        job.next_attempt_at = None
        event_outbox_service.enqueue_event(
            db,
            event_type="economy.bulk_grant.completed.v1",
            actor_user_id=job.actor_user_id,
            payload={
                "grant_id": job.grant_id,
                "coin_amount": int(job.coin_amount),
                "active_only": bool(job.active_only),
                "eligible_count": int(job.eligible_count),
                "processed_count": int(job.processed_count),
            },
        )
        db.commit()
        return {
            "status": "COMPLETED",
            "processed": 0,
            "processed_count": int(job.processed_count),
        }

    batch_business_reference = (
        f"bulk-grant:{job.grant_id}:after:{int(job.last_user_id or 0)}"
    )
    context = economy_service_client.mutation_context(
        "bulk_grant.batch",
        batch_business_reference,
    )
    tx, cached = economy_transaction_service.begin(
        db,
        transaction_id=context["transaction_id"],
        idempotency_key=context["idempotency_key"],
        business_reference=context["business_reference"],
        operation_type="bulk_grant.batch",
        actor_user_id=job.actor_user_id,
        request_payload={
            "grant_id": job.grant_id,
            "after_user_id": int(job.last_user_id or 0),
            "user_ids": user_ids,
            "coin_amount": int(job.coin_amount),
        },
    )
    if cached is not None:
        db.rollback()
        return {
            "status": "RUNNING",
            "processed": 0,
            "processed_count": int(job.processed_count),
            "cursor": int(job.last_user_id),
            "duplicate_batch": True,
        }

    existing_ids = {
        int(row[0])
        for row in (
            db.query(EconomyBulkGrantRecipient.user_id)
            .filter(
                EconomyBulkGrantRecipient.grant_id == job.grant_id,
                EconomyBulkGrantRecipient.user_id.in_(user_ids),
            )
            .all()
        )
    }
    new_ids = [user_id for user_id in user_ids if user_id not in existing_ids]
    wallets = _wallets_for_update(db, new_ids) if new_ids else {}

    for user_id in new_ids:
        wallet = wallets[user_id]
        before = int(wallet.coin_balance or 0)
        after = before + int(job.coin_amount)
        wallet.coin_balance = after
        db.add(
            WalletLedger(
                user_id=user_id,
                currency_type=EconomyCurrency.COIN.value,
                direction=EconomyDirection.CREDIT.value,
                amount=int(job.coin_amount),
                before_balance=before,
                after_balance=after,
                source_type="SUPER_OWNER_SEND_ALL",
                source_id=job.grant_id,
                transaction_id=tx.transaction_id,
                idempotency_key=tx.idempotency_key,
                business_reference=tx.business_reference,
                created_by_user_id=job.actor_user_id,
                reason=job.reason,
            )
        )
        economy_transaction_service.record_balanced_transfer(
            db,
            tx=tx,
            currency=EconomyCurrency.COIN.value,
            amount=int(job.coin_amount),
            debit_account="SYSTEM_BULK_GRANT:COIN",
            credit_account=f"USER_WALLET:{user_id}:COIN",
            source_type="SUPER_OWNER_SEND_ALL",
            credit_user_id=user_id,
        )
        db.add(
            EconomyBulkGrantRecipient(
                grant_id=job.grant_id,
                user_id=user_id,
                amount=int(job.coin_amount),
            )
        )

    job.last_user_id = max(user_ids)
    job.processed_count = int(job.processed_count or 0) + len(new_ids)
    job.status = "RUNNING"
    job.lease_owner = None
    job.lease_until = None
    job.next_attempt_at = datetime.utcnow()
    job.last_error = None
    db.add(job)
    result = {
        "status": "RUNNING",
        "processed": len(new_ids),
        "processed_count": int(job.processed_count),
        "cursor": int(job.last_user_id),
    }
    economy_transaction_service.complete(
        db,
        tx=tx,
        result=result,
        event_type="economy.bulk_grant.batch_applied.v1",
        event_payload={
            "grant_id": job.grant_id,
            "processed": len(new_ids),
            "processed_count": int(job.processed_count),
            "cursor": int(job.last_user_id),
            "coin_amount": int(job.coin_amount),
        },
    )
    return result


def mark_attempt_failed(
    db: Session,
    *,
    job_id: int,
    worker_id: str,
    error: str,
) -> None:
    job = (
        db.query(EconomyBulkGrant)
        .filter(EconomyBulkGrant.id == job_id)
        .with_for_update()
        .first()
    )
    if job is None or job.status == "COMPLETED":
        db.rollback()
        return
    if job.lease_owner not in {None, worker_id}:
        db.rollback()
        return
    job.failure_count = int(job.failure_count or 0) + 1
    backoff = min(300, 2 ** min(job.failure_count, 8))
    job.status = "RETRY"
    job.lease_owner = None
    job.lease_until = None
    job.next_attempt_at = datetime.utcnow() + timedelta(seconds=backoff)
    job.last_error = str(error)[:2000]
    db.add(job)
    db.commit()
