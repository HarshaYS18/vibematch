"""Thread-safe low-cardinality metrics for the Kafka bridge."""

from __future__ import annotations

from collections import Counter
from threading import Lock

_lock = Lock()
_counts: Counter[tuple[str, str]] = Counter()
_in_flight = 0
_source_pending = 0
_source_ack_pending = 0
_source_redelivered = 0
_publish_buckets = (0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0)
_publish_hist: Counter[tuple[str, float]] = Counter()
_publish_count: Counter[str] = Counter()
_publish_sum: Counter[str] = Counter()


def count(name: str, family: str = "all", amount: int = 1) -> None:
    with _lock:
        _counts[(name, family)] += amount


def set_in_flight(delta: int) -> None:
    global _in_flight
    with _lock:
        _in_flight = max(0, _in_flight + delta)


def set_source_lag(*, pending: int, ack_pending: int, redelivered: int) -> None:
    global _source_pending, _source_ack_pending, _source_redelivered
    with _lock:
        _source_pending = max(0, int(pending))
        _source_ack_pending = max(0, int(ack_pending))
        _source_redelivered = max(0, int(redelivered))


def observe_publish(family: str, seconds: float) -> None:
    value = max(0.0, float(seconds))
    with _lock:
        _publish_count[family] += 1
        _publish_sum[family] += value
        for bucket in _publish_buckets:
            if value <= bucket:
                _publish_hist[(family, bucket)] += 1


def render(*, ready: bool, nats_connected: bool, kafka_ready: bool) -> str:
    with _lock:
        counts = dict(_counts)
        in_flight = _in_flight
        hist = dict(_publish_hist)
        publish_count = dict(_publish_count)
        publish_sum = dict(_publish_sum)
        source_pending = _source_pending
        source_ack_pending = _source_ack_pending
        source_redelivered = _source_redelivered

    lines = [
        "# TYPE funkey_kafka_bridge_ready gauge",
        f"funkey_kafka_bridge_ready {1 if ready else 0}",
        "# TYPE funkey_kafka_bridge_nats_connected gauge",
        f"funkey_kafka_bridge_nats_connected {1 if nats_connected else 0}",
        "# TYPE funkey_kafka_bridge_kafka_ready gauge",
        f"funkey_kafka_bridge_kafka_ready {1 if kafka_ready else 0}",
        "# TYPE funkey_kafka_bridge_in_flight gauge",
        f"funkey_kafka_bridge_in_flight {in_flight}",
        "# TYPE funkey_kafka_bridge_source_pending gauge",
        f"funkey_kafka_bridge_source_pending {source_pending}",
        "# TYPE funkey_kafka_bridge_source_ack_pending gauge",
        f"funkey_kafka_bridge_source_ack_pending {source_ack_pending}",
        "# TYPE funkey_kafka_bridge_source_redelivered gauge",
        f"funkey_kafka_bridge_source_redelivered {source_redelivered}",
        "# TYPE funkey_kafka_bridge_events_total counter",
    ]
    for (name, family), value in sorted(counts.items()):
        lines.append(f'funkey_kafka_bridge_events_total{{result="{name}",family="{family}"}} {value}')

    lines.append("# TYPE funkey_kafka_bridge_publish_duration_seconds histogram")
    for family, total in sorted(publish_count.items()):
        for bucket in _publish_buckets:
            lines.append(
                f'funkey_kafka_bridge_publish_duration_seconds_bucket{{family="{family}",le="{bucket:g}"}} '
                f'{hist.get((family, bucket), 0)}'
            )
        lines.append(
            f'funkey_kafka_bridge_publish_duration_seconds_bucket{{family="{family}",le="+Inf"}} {total}'
        )
        lines.append(
            f'funkey_kafka_bridge_publish_duration_seconds_count{{family="{family}"}} {total}'
        )
        lines.append(
            f'funkey_kafka_bridge_publish_duration_seconds_sum{{family="{family}"}} '
            f'{publish_sum.get(family, 0.0):.9f}'
        )
    return "\n".join(lines) + "\n"
