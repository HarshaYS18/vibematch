"""Immutable persisted-query allowlist for Chunk 36."""

from __future__ import annotations

import hashlib
from dataclasses import dataclass

from graphql import DocumentNode, parse


def _canonical(text: str) -> str:
    return "\n".join(line.rstrip() for line in text.strip().splitlines()) + "\n"


@dataclass(frozen=True)
class PersistedOperation:
    name: str
    operation_id: str
    query: str
    document: DocumentNode


_RAW_OPERATIONS: tuple[tuple[str, str, str], ...] = (
    (
        "HomeComposite",
        "49caa7816c5a823071f7b812cfcc35b6ee996fe337da55dce98f121c776c16f6",
        """query HomeComposite {
  home {
    myRoom
    eventBanners
    policyBanners
  }
}""",
    ),
    (
        "ProfileComposite",
        "84f74379f8353663a757b7d3550e710a352e4a2d6b6b3e9ee1f15cb6681927bf",
        """query ProfileComposite($publicUserId: String!, $vibeLimit: Int = 12) {
  profile(publicUserId: $publicUserId, vibeLimit: $vibeLimit) {
    profile
    vibes
    followStatus
  }
}""",
    ),
    (
        "DiscoveryComposite",
        "f6c1566209c436ef1d2739366111c9b3ca251fb3bb4ed29195fb038c8be0766e",
        """query DiscoveryComposite($vibeLimit: Int = 20, $rankingLimit: Int = 20) {
  discovery(vibeLimit: $vibeLimit, rankingLimit: $rankingLimit) {
    vibes
    rankings
    banners
  }
}""",
    ),
    (
        "CreatorAdminDashboard",
        "f54ff76c9aa11351397d600ebf1d9a3faa17e071d4735bcc2604b678b6329f84",
        """query CreatorAdminDashboard($reportLimit: Int = 20) {
  creatorAdminDashboard(reportLimit: $reportLimit) {
    controlSummary
    auditLogs
    vibeReports
  }
}""",
    ),
)


def _build_registry() -> dict[str, PersistedOperation]:
    registry: dict[str, PersistedOperation] = {}
    for name, expected_id, raw_query in _RAW_OPERATIONS:
        query = _canonical(raw_query)
        actual_id = hashlib.sha256(query.encode("utf-8")).hexdigest()
        if actual_id != expected_id:
            raise RuntimeError(
                f"Persisted query hash mismatch for {name}: "
                f"expected {expected_id}, got {actual_id}"
            )
        if expected_id in registry:
            raise RuntimeError(f"Duplicate persisted operation id: {expected_id}")
        registry[expected_id] = PersistedOperation(
            name=name,
            operation_id=expected_id,
            query=query,
            document=parse(query),
        )
    return registry


OPERATIONS = _build_registry()
OPERATIONS_BY_NAME = {operation.name: operation for operation in OPERATIONS.values()}
