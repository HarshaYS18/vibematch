"""Deterministic, explainable recommendation scoring primitives."""

from __future__ import annotations

import math
from datetime import datetime, timezone

from contracts import RecommendationSignal


HALF_LIFE_SECONDS = 6 * 60 * 60


def decayed_weight(signal: RecommendationSignal, *, now: datetime | None = None) -> float:
    now = now or datetime.now(timezone.utc)
    age = max(0.0, (now - signal.occurred_at).total_seconds())
    decay = math.pow(0.5, age / HALF_LIFE_SECONDS)
    return signal.weight * decay


def stable_tiebreak(member: str) -> float:
    # Tiny deterministic tie-breaker; never dominates a behavioral score.
    return (sum(member.encode("utf-8")) % 1000) / 1_000_000.0


def score(signal: RecommendationSignal, *, now: datetime | None = None) -> float:
    return decayed_weight(signal, now=now) + stable_tiebreak(signal.member)
