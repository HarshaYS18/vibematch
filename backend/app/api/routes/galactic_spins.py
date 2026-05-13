from __future__ import annotations

import hashlib
import hmac
import secrets
from datetime import datetime, timezone
from enum import Enum
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.models.wallet import WalletCurrency, WalletLedgerDirection, WalletLedgerSource
from app.services.wallet_service import (
    get_or_create_game_house_pool,
    get_or_create_wallet,
    move_wallet_balance,
    record_game_ledger,
)


router = APIRouter(prefix="/games/galactic-spins", tags=["Games - Galactic Spins"])


class SlotSymbol(str, Enum):
    WILD = "wild"
    DIAMOND = "diamond"
    SEVEN = "seven"
    BAR = "bar"
    GRAPES = "grapes"
    CHERRIES = "cherries"
    ORANGE = "orange"


class SpinRiskTier(str, Enum):
    NORMAL = "normal"
    WATCH = "watch"
    WHALE = "whale"
    HOUSE_PROTECT = "house_protect"


class SpinMode(str, Enum):
    WALLET_COINS = "wallet_coins"


class GalacticConfigResponse(BaseModel):
    game_id: str
    version: str
    reels: int
    rows: int
    min_bet: int
    max_bet: int
    allowed_lines: list[int]
    symbols: list[str]
    paytable: dict[str, dict[str, int]]
    fairness_note: str
    economy_note: str


class GalacticSessionRequest(BaseModel):
    mode: SpinMode = SpinMode.WALLET_COINS


class GalacticSessionResponse(BaseModel):
    session_id: str
    balance: int
    mode: SpinMode
    created_at: datetime
    house_reserve: int
    max_single_spin_payout: int


class GalacticSpinRequest(BaseModel):
    session_id: str = Field(min_length=16, max_length=96)
    bet: int = Field(ge=10, le=100_000)
    lines: int = Field(default=25, ge=1, le=25)
    client_seed: str | None = Field(default=None, max_length=96)
    idempotency_key: str | None = Field(default=None, max_length=160)


class GalacticSpinResponse(BaseModel):
    session_id: str
    spin_id: str
    reels: list[list[str]]
    paylines: list[dict[str, Any]]
    bet: int
    gross_win: int
    capped_win: int
    net_change: int
    balance: int
    risk_tier: SpinRiskTier
    house_reserve: int
    server_seed_hash: str
    economy_events: list[str]
    wallet_bet_ledger_id: int | None
    wallet_win_ledger_id: int | None
    created_at: datetime


class _SessionState(BaseModel):
    session_id: str
    owner_user_id: int
    mode: SpinMode
    created_at: datetime
    total_bet: int = 0
    total_paid: int = 0
    consecutive_high_bets: int = 0


GAME_ID = "galactic_spins"
ROWS = 3
REELS = 5
ALLOWED_LINES = [1, 5, 10, 15, 20, 25]
SERVER_SECRET = "replace-with-env-secret-before-production"
HOUSE_START_RESERVE = 5_000_000
_SESSIONS: dict[str, _SessionState] = {}

SYMBOL_WEIGHTS: list[tuple[SlotSymbol, int]] = [
    (SlotSymbol.ORANGE, 26),
    (SlotSymbol.CHERRIES, 22),
    (SlotSymbol.GRAPES, 18),
    (SlotSymbol.BAR, 14),
    (SlotSymbol.SEVEN, 10),
    (SlotSymbol.DIAMOND, 7),
    (SlotSymbol.WILD, 3),
]

PAYTABLE: dict[SlotSymbol, dict[int, int]] = {
    SlotSymbol.ORANGE: {3: 2, 4: 5, 5: 12},
    SlotSymbol.CHERRIES: {3: 3, 4: 8, 5: 18},
    SlotSymbol.GRAPES: {3: 4, 4: 10, 5: 25},
    SlotSymbol.BAR: {3: 6, 4: 18, 5: 45},
    SlotSymbol.SEVEN: {3: 10, 4: 35, 5: 90},
    SlotSymbol.DIAMOND: {3: 18, 4: 65, 5: 180},
    SlotSymbol.WILD: {3: 25, 4: 100, 5: 300},
}

PAYLINES = [
    [1, 1, 1, 1, 1], [0, 0, 0, 0, 0], [2, 2, 2, 2, 2], [0, 1, 2, 1, 0], [2, 1, 0, 1, 2],
    [0, 0, 1, 2, 2], [2, 2, 1, 0, 0], [1, 0, 0, 0, 1], [1, 2, 2, 2, 1], [0, 1, 1, 1, 0],
    [2, 1, 1, 1, 2], [1, 0, 1, 2, 1], [1, 2, 1, 0, 1], [0, 1, 0, 1, 0], [2, 1, 2, 1, 2],
    [1, 1, 0, 1, 1], [1, 1, 2, 1, 1], [0, 2, 0, 2, 0], [2, 0, 2, 0, 2], [0, 2, 2, 2, 0],
    [2, 0, 0, 0, 2], [0, 0, 2, 0, 0], [2, 2, 0, 2, 2], [1, 0, 2, 0, 1], [1, 2, 0, 2, 1],
]


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _hash_seed(seed: str) -> str:
    return hashlib.sha256(seed.encode("utf-8")).hexdigest()


def _make_rng_material(session: _SessionState, request: GalacticSpinRequest, spin_id: str) -> bytes:
    client_seed = request.client_seed or "no-client-seed"
    message = f"{session.session_id}:{session.owner_user_id}:{session.total_bet}:{request.bet}:{request.lines}:{client_seed}:{spin_id}"
    return hmac.new(SERVER_SECRET.encode("utf-8"), message.encode("utf-8"), hashlib.sha256).digest()


def _rand01(material: bytes, nonce: int) -> float:
    digest = hmac.new(material, str(nonce).encode("utf-8"), hashlib.sha256).digest()
    return int.from_bytes(digest[:8], "big") / float(2**64 - 1)


def _choose_symbol(material: bytes, nonce: int, risk_tier: SpinRiskTier) -> SlotSymbol:
    weights = SYMBOL_WEIGHTS.copy()
    if risk_tier == SpinRiskTier.WHALE:
        weights = [(s, max(1, w - 2) if s in {SlotSymbol.WILD, SlotSymbol.DIAMOND, SlotSymbol.SEVEN} else w + 1) for s, w in weights]
    elif risk_tier == SpinRiskTier.HOUSE_PROTECT:
        weights = [(s, max(1, w - 4) if s in {SlotSymbol.WILD, SlotSymbol.DIAMOND, SlotSymbol.SEVEN, SlotSymbol.BAR} else w + 2) for s, w in weights]

    total = sum(weight for _, weight in weights)
    pick = _rand01(material, nonce) * total
    cumulative = 0.0
    for symbol, weight in weights:
        cumulative += weight
        if pick <= cumulative:
            return symbol
    return SlotSymbol.ORANGE


def _risk_tier(session: _SessionState, bet: int, house_reserve: int) -> SpinRiskTier:
    exposure_ratio = bet / max(house_reserve, 1)
    session_loss = max(session.total_paid - session.total_bet, 0)
    user_pressure_ratio = session_loss / max(house_reserve, 1)
    if house_reserve < HOUSE_START_RESERVE * 0.72 or exposure_ratio >= 0.015:
        return SpinRiskTier.HOUSE_PROTECT
    if bet >= 50_000 or session.consecutive_high_bets >= 3 or user_pressure_ratio >= 0.03:
        return SpinRiskTier.WHALE
    if bet >= 10_000 or house_reserve < HOUSE_START_RESERVE * 0.86:
        return SpinRiskTier.WATCH
    return SpinRiskTier.NORMAL


def _max_payout_for_spin(bet: int, tier: SpinRiskTier, house_reserve: int) -> int:
    if tier == SpinRiskTier.HOUSE_PROTECT:
        reserve_cap = int(house_reserve * 0.004)
        bet_cap = bet * 12
    elif tier == SpinRiskTier.WHALE:
        reserve_cap = int(house_reserve * 0.008)
        bet_cap = bet * 25
    elif tier == SpinRiskTier.WATCH:
        reserve_cap = int(house_reserve * 0.012)
        bet_cap = bet * 45
    else:
        reserve_cap = int(house_reserve * 0.02)
        bet_cap = bet * 80
    return max(bet, min(reserve_cap, bet_cap, 250_000))


def _build_reels(material: bytes, risk_tier: SpinRiskTier) -> list[list[SlotSymbol]]:
    reels: list[list[SlotSymbol]] = []
    nonce = 1
    for _ in range(REELS):
        column: list[SlotSymbol] = []
        for _ in range(ROWS):
            column.append(_choose_symbol(material, nonce, risk_tier))
            nonce += 1
        reels.append(column)
    return reels


def _line_symbol_match(first: SlotSymbol, current: SlotSymbol) -> bool:
    return first == current or first == SlotSymbol.WILD or current == SlotSymbol.WILD


def _score_reels(reels: list[list[SlotSymbol]], bet: int, lines: int) -> tuple[int, list[dict[str, Any]]]:
    stake_per_line = max(1, bet // max(lines, 1))
    total = 0
    wins: list[dict[str, Any]] = []
    for index, path in enumerate(PAYLINES[:lines]):
        match_symbol = reels[0][path[0]]
        match_count = 1
        for reel_index in range(1, REELS):
            candidate = reels[reel_index][path[reel_index]]
            if not _line_symbol_match(match_symbol, candidate):
                break
            if match_symbol == SlotSymbol.WILD and candidate != SlotSymbol.WILD:
                match_symbol = candidate
            match_count += 1
        multiplier = PAYTABLE.get(match_symbol, {}).get(match_count, 0)
        if multiplier > 0:
            line_win = stake_per_line * multiplier
            total += line_win
            wins.append({"line": index + 1, "path": path, "symbol": match_symbol.value, "matches": match_count, "multiplier": multiplier, "win": line_win})
    return total, wins


def _serialize_reels(reels: list[list[SlotSymbol]]) -> list[list[str]]:
    return [[symbol.value for symbol in column] for column in reels]


@router.get("/config", response_model=GalacticConfigResponse)
def get_galactic_spins_config():
    return GalacticConfigResponse(
        game_id=GAME_ID,
        version="mvp-wallet-1.0",
        reels=REELS,
        rows=ROWS,
        min_bet=10,
        max_bet=100_000,
        allowed_lines=ALLOWED_LINES,
        symbols=[symbol.value for symbol in SlotSymbol],
        paytable={symbol.value: {str(k): v for k, v in table.items()} for symbol, table in PAYTABLE.items()},
        fairness_note="Backend-authoritative HMAC RNG. Replace SERVER_SECRET with env secret before production.",
        economy_note="Wallet ledger connected MVP: every bet is debited, every win is credited, game ledger records house exposure.",
    )


@router.post("/sessions", response_model=GalacticSessionResponse)
def create_galactic_spins_session(
    payload: GalacticSessionRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    wallet = get_or_create_wallet(db, current_user)
    pool = get_or_create_game_house_pool(db, game_id=GAME_ID)
    session_id = secrets.token_urlsafe(24)
    session = _SessionState(session_id=session_id, owner_user_id=current_user.id, mode=payload.mode, created_at=_utc_now())
    _SESSIONS[session_id] = session
    return GalacticSessionResponse(
        session_id=session_id,
        balance=wallet.coin_balance,
        mode=session.mode,
        created_at=session.created_at,
        house_reserve=pool.coin_reserve,
        max_single_spin_payout=250_000,
    )


@router.post("/spin", response_model=GalacticSpinResponse)
def spin_galactic_spins(
    payload: GalacticSpinRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    session = _SESSIONS.get(payload.session_id)
    if not session or session.owner_user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Game session not found")
    if payload.lines not in ALLOWED_LINES:
        raise HTTPException(status_code=400, detail="Invalid line count")

    wallet = get_or_create_wallet(db, current_user)
    pool = get_or_create_game_house_pool(db, game_id=GAME_ID)
    wallet = db.query(type(wallet)).filter(type(wallet).id == wallet.id).with_for_update().first()
    pool = db.query(type(pool)).filter(type(pool).id == pool.id).with_for_update().first()
    if wallet is None or pool is None:
        raise HTTPException(status_code=500, detail="Wallet or house pool not found")
    if wallet.coin_balance < payload.bet:
        raise HTTPException(status_code=400, detail="Insufficient wallet balance")
    if payload.bet >= 10_000:
        session.consecutive_high_bets += 1
    else:
        session.consecutive_high_bets = 0

    risk_tier = _risk_tier(session, payload.bet, pool.coin_reserve)
    max_payout = _max_payout_for_spin(payload.bet, risk_tier, pool.coin_reserve)
    spin_id = secrets.token_urlsafe(18)
    base_key = payload.idempotency_key or f"{GAME_ID}:{payload.session_id}:{spin_id}:{current_user.id}"
    server_seed_hash = _hash_seed(f"{SERVER_SECRET}:{spin_id}:{payload.session_id}")
    material = _make_rng_material(session, payload, spin_id)
    reels = _build_reels(material, risk_tier)
    gross_win, paylines = _score_reels(reels, payload.bet, payload.lines)
    capped_win = min(gross_win, max_payout, max(pool.coin_reserve, 0))
    house_before = pool.coin_reserve

    bet_move = move_wallet_balance(
        db,
        user=current_user,
        currency=WalletCurrency.COINS,
        direction=WalletLedgerDirection.DEBIT,
        source=WalletLedgerSource.GAME_BET,
        amount=payload.bet,
        idempotency_key=f"{base_key}:bet",
        reference_type="game_spin",
        reference_id=spin_id,
        reason="Galactic Spins bet",
        metadata_json={"game_id": GAME_ID, "session_id": payload.session_id, "lines": payload.lines},
    )
    wallet_win_ledger_id: int | None = None
    if capped_win > 0:
        win_move = move_wallet_balance(
            db,
            user=current_user,
            currency=WalletCurrency.COINS,
            direction=WalletLedgerDirection.CREDIT,
            source=WalletLedgerSource.GAME_WIN,
            amount=capped_win,
            idempotency_key=f"{base_key}:win",
            reference_type="game_spin",
            reference_id=spin_id,
            reason="Galactic Spins win",
            metadata_json={"game_id": GAME_ID, "session_id": payload.session_id, "gross_win": gross_win, "risk_tier": risk_tier.value},
        )
        wallet = win_move.wallet
        wallet_win_ledger_id = win_move.ledger_entry.id
    else:
        wallet = bet_move.wallet

    pool.coin_reserve = pool.coin_reserve + payload.bet - capped_win
    pool.lifetime_coin_in += payload.bet
    pool.lifetime_coin_out += capped_win
    session.total_bet += payload.bet
    session.total_paid += capped_win
    _SESSIONS[payload.session_id] = session

    events: list[str] = []
    if gross_win > capped_win:
        events.append("PAYOUT_CAPPED_BY_HOUSE_EXPOSURE")
    if risk_tier in {SpinRiskTier.WHALE, SpinRiskTier.HOUSE_PROTECT}:
        events.append(f"RISK_TIER_{risk_tier.value.upper()}")
    if capped_win >= payload.bet * 25:
        events.append("GLOBAL_BROADCAST_ELIGIBLE")

    record_game_ledger(
        db,
        game_id=GAME_ID,
        user=current_user,
        session_id=payload.session_id,
        spin_id=spin_id,
        bet_amount=payload.bet,
        win_amount=capped_win,
        risk_tier=risk_tier.value,
        house_reserve_before=house_before,
        house_reserve_after=pool.coin_reserve,
        idempotency_key=f"{base_key}:game_ledger",
        metadata_json={"reels": _serialize_reels(reels), "paylines": paylines, "events": events, "server_seed_hash": server_seed_hash},
    )

    db.add(pool)
    db.commit()
    db.refresh(wallet)
    db.refresh(pool)

    return GalacticSpinResponse(
        session_id=session.session_id,
        spin_id=spin_id,
        reels=_serialize_reels(reels),
        paylines=paylines,
        bet=payload.bet,
        gross_win=gross_win,
        capped_win=capped_win,
        net_change=capped_win - payload.bet,
        balance=wallet.coin_balance,
        risk_tier=risk_tier,
        house_reserve=pool.coin_reserve,
        server_seed_hash=server_seed_hash,
        economy_events=events,
        wallet_bet_ledger_id=bet_move.ledger_entry.id,
        wallet_win_ledger_id=wallet_win_ledger_id,
        created_at=_utc_now(),
    )
