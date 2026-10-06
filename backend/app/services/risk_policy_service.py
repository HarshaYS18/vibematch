"""Central deterministic trust/fraud risk aggregation.

This module produces advisory/review decisions. Domain owners retain mutation
authority and must record their own durable enforcement/audit evidence.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class RiskSignal:
    name: str
    score: int
    reason_code: str


@dataclass(frozen=True)
class RiskDecision:
    score: int
    action: str
    reasons: tuple[str, ...]


def evaluate(signals: list[RiskSignal]) -> RiskDecision:
    if not signals:
        return RiskDecision(score=0, action="allow", reasons=())

    bounded = [max(0, min(int(signal.score), 100)) for signal in signals]
    # Max signal dominates; smaller corroborating signals add bounded evidence
    # without allowing a large list of weak signals to exceed 100.
    top = max(bounded)
    corroboration = min(20, sum(score for score in bounded if score != top) // 10)
    score = min(100, top + corroboration)

    if score >= 90:
        action = "temporary_hold_and_manual_review"
    elif score >= 70:
        action = "manual_review"
    elif score >= 40:
        action = "observe"
    else:
        action = "allow"

    reasons = tuple(sorted({signal.reason_code for signal in signals if signal.reason_code}))
    return RiskDecision(score=score, action=action, reasons=reasons)
