"""Environment-only configuration for the read-only GraphQL BFF."""

from __future__ import annotations

import os
from dataclasses import dataclass


def _float(name: str, default: float) -> float:
    raw = os.getenv(name, "").strip()
    return float(raw) if raw else default


def _int(name: str, default: int) -> int:
    raw = os.getenv(name, "").strip()
    return int(raw) if raw else default


@dataclass(frozen=True)
class Settings:
    core_url: str = os.getenv("GRAPHQL_CORE_URL", "http://funkey-api:8000/api/v1").rstrip("/")
    profile_social_url: str = os.getenv(
        "GRAPHQL_PROFILE_SOCIAL_URL",
        "http://funkey-profile-social:8087/api/v1",
    ).rstrip("/")
    vibes_url: str = os.getenv(
        "GRAPHQL_VIBES_URL",
        "http://funkey-vibes:8084/api/v1",
    ).rstrip("/")
    upstream_timeout_seconds: float = _float("GRAPHQL_UPSTREAM_TIMEOUT_SECONDS", 2.5)
    max_parallel_upstreams: int = _int("GRAPHQL_MAX_PARALLEL_UPSTREAMS", 8)
    max_request_bytes: int = _int("GRAPHQL_MAX_REQUEST_BYTES", 16 * 1024)
    max_depth: int = _int("GRAPHQL_MAX_DEPTH", 4)
    max_complexity: int = _int("GRAPHQL_MAX_COMPLEXITY", 30)


settings = Settings()
