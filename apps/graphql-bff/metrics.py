"""Minimal low-cardinality Prometheus text metrics for the BFF."""

from __future__ import annotations

from collections import Counter
from threading import Lock

_lock = Lock()
_counts: Counter[str] = Counter()


def increment(name: str) -> None:
    with _lock:
        _counts[name] += 1


def render() -> str:
    with _lock:
        snapshot = dict(_counts)
    lines = [
        "# HELP funkey_graphql_requests_total GraphQL persisted requests.",
        "# TYPE funkey_graphql_requests_total counter",
        f"funkey_graphql_requests_total {snapshot.get('requests', 0)}",
        "# HELP funkey_graphql_rejected_total GraphQL requests rejected before execution.",
        "# TYPE funkey_graphql_rejected_total counter",
        f"funkey_graphql_rejected_total {snapshot.get('rejected', 0)}",
        "# HELP funkey_graphql_execution_errors_total GraphQL execution errors.",
        "# TYPE funkey_graphql_execution_errors_total counter",
        f"funkey_graphql_execution_errors_total {snapshot.get('execution_errors', 0)}",
    ]
    return "\n".join(lines) + "\n"
