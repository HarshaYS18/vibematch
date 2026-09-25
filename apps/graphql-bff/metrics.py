"""Low-cardinality Prometheus counters and latency histograms for the GraphQL BFF."""

from __future__ import annotations

from collections import Counter, defaultdict
from threading import Lock

_lock = Lock()
_counts: Counter[str] = Counter()

_OPERATION_BUCKETS = (0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5)
_UPSTREAM_BUCKETS = (0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5)

_operation_bucket_counts: Counter[tuple[str, str, float]] = Counter()
_operation_counts: Counter[tuple[str, str]] = Counter()
_operation_sums: dict[tuple[str, str], float] = defaultdict(float)

_upstream_bucket_counts: Counter[tuple[str, str, float]] = Counter()
_upstream_counts: Counter[tuple[str, str]] = Counter()
_upstream_sums: dict[tuple[str, str], float] = defaultdict(float)


def increment(name: str) -> None:
    """Increment one fixed transport/execution counter."""
    with _lock:
        _counts[name] += 1


def _observe(
    label: str,
    seconds: float,
    outcome: str,
    *,
    buckets: tuple[float, ...],
    bucket_counts: Counter[tuple[str, str, float]],
    counts: Counter[tuple[str, str]],
    sums: dict[tuple[str, str], float],
) -> None:
    """Record one cumulative histogram observation under bounded labels."""
    if not label:
        raise ValueError("metric label must be non-empty")
    if outcome not in {"ok", "error"}:
        raise ValueError("metric outcome must be 'ok' or 'error'")

    duration = max(0.0, float(seconds))
    key = (label, outcome)
    with _lock:
        counts[key] += 1
        sums[key] += duration
        for bucket in buckets:
            if duration <= bucket:
                bucket_counts[(label, outcome, bucket)] += 1


def observe_operation(operation: str, seconds: float, *, outcome: str) -> None:
    """Record total accepted-request BFF latency by persisted operation name."""
    _observe(
        operation,
        seconds,
        outcome,
        buckets=_OPERATION_BUCKETS,
        bucket_counts=_operation_bucket_counts,
        counts=_operation_counts,
        sums=_operation_sums,
    )


def observe_upstream(service: str, seconds: float, *, outcome: str) -> None:
    """Record owner-service read latency by the fixed service identifier."""
    _observe(
        service,
        seconds,
        outcome,
        buckets=_UPSTREAM_BUCKETS,
        bucket_counts=_upstream_bucket_counts,
        counts=_upstream_counts,
        sums=_upstream_sums,
    )


def _escape_label(value: str) -> str:
    """Escape a Prometheus label value without changing its cardinality."""
    return value.replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')


def _number(value: int | float) -> str:
    """Render counters and sums compactly for Prometheus text exposition."""
    if isinstance(value, int):
        return str(value)
    return format(value, ".12g")


def _render_histogram(
    *,
    metric: str,
    help_text: str,
    label_name: str,
    buckets: tuple[float, ...],
    bucket_counts: dict[tuple[str, str, float], int],
    counts: dict[tuple[str, str], int],
    sums: dict[tuple[str, str], float],
) -> list[str]:
    """Render one standards-compatible cumulative Prometheus histogram."""
    lines = [
        f"# HELP {metric} {help_text}",
        f"# TYPE {metric} histogram",
    ]
    for (label, outcome), count in sorted(counts.items()):
        escaped_label = _escape_label(label)
        escaped_outcome = _escape_label(outcome)
        base_labels = (
            f'{label_name}="{escaped_label}",outcome="{escaped_outcome}"'
        )
        for bucket in buckets:
            bucket_count = bucket_counts.get((label, outcome, bucket), 0)
            lines.append(
                f'{metric}_bucket{{{base_labels},le="{bucket:g}"}} '
                f"{bucket_count}"
            )
        lines.append(f'{metric}_bucket{{{base_labels},le="+Inf"}} {count}')
        lines.append(
            f"{metric}_sum{{{base_labels}}} "
            f"{_number(sums.get((label, outcome), 0.0))}"
        )
        lines.append(f"{metric}_count{{{base_labels}}} {count}")
    return lines


def render() -> str:
    """Render a consistent snapshot of GraphQL counters and histograms."""
    with _lock:
        counter_snapshot = dict(_counts)
        operation_buckets = dict(_operation_bucket_counts)
        operation_counts = dict(_operation_counts)
        operation_sums = dict(_operation_sums)
        upstream_buckets = dict(_upstream_bucket_counts)
        upstream_counts = dict(_upstream_counts)
        upstream_sums = dict(_upstream_sums)

    lines = [
        "# HELP funkey_graphql_requests_total GraphQL persisted requests.",
        "# TYPE funkey_graphql_requests_total counter",
        f"funkey_graphql_requests_total {counter_snapshot.get('requests', 0)}",
        "# HELP funkey_graphql_rejected_total GraphQL requests rejected before execution.",
        "# TYPE funkey_graphql_rejected_total counter",
        f"funkey_graphql_rejected_total {counter_snapshot.get('rejected', 0)}",
        "# HELP funkey_graphql_execution_errors_total GraphQL execution errors.",
        "# TYPE funkey_graphql_execution_errors_total counter",
        f"funkey_graphql_execution_errors_total {counter_snapshot.get('execution_errors', 0)}",
    ]
    lines.extend(
        _render_histogram(
            metric="funkey_graphql_operation_duration_seconds",
            help_text="Accepted persisted GraphQL request latency by operation.",
            label_name="operation",
            buckets=_OPERATION_BUCKETS,
            bucket_counts=operation_buckets,
            counts=operation_counts,
            sums=operation_sums,
        )
    )
    lines.extend(
        _render_histogram(
            metric="funkey_graphql_upstream_duration_seconds",
            help_text="GraphQL owner-service read latency by service.",
            label_name="service",
            buckets=_UPSTREAM_BUCKETS,
            bucket_counts=upstream_buckets,
            counts=upstream_counts,
            sums=upstream_sums,
        )
    )
    return "\n".join(lines) + "\n"
