"""Route-specific database query budgets for hot read paths.

Budgets are intentionally conservative ceilings, not performance targets. CI
tests keep representative query counts below these limits; production only
emits telemetry on breaches so correctness is never coupled to instrumentation.
"""

from __future__ import annotations


ROUTE_QUERY_BUDGETS: dict[tuple[str, str], int] = {
    ("GET", "/api/v1/vibes/feed"): 6,
    ("GET", "/api/v1/vibes/friends"): 6,
    ("GET", "/api/v1/vibes/saved"): 6,
    ("GET", "/api/v1/inbox/conversations"): 8,
    ("GET", "/api/v1/inbox/conversations/{conversation_id}/messages"): 8,
}


def query_budget_for(method: str, route: str) -> int | None:
    return ROUTE_QUERY_BUDGETS.get((method.upper(), route))
