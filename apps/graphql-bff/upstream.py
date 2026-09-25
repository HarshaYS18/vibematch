"""Bounded read-only HTTP composition client with upstream latency telemetry."""

from __future__ import annotations

import asyncio
from dataclasses import dataclass
from time import perf_counter

import httpx
from graphql import GraphQLError
from opentelemetry import trace

from config import settings
from metrics import observe_upstream

tracer = trace.get_tracer("funkey.graphql_bff")


@dataclass(frozen=True)
class RequestMetadata:
    """Headers that must propagate across every owner-service read."""

    authorization: str
    request_id: str
    traceparent: str | None


class UpstreamClient:
    """GET-only owner-service client scoped to one GraphQL request."""

    def __init__(self, client: httpx.AsyncClient, metadata: RequestMetadata) -> None:
        self._client = client
        self._metadata = metadata
        self._semaphore = asyncio.Semaphore(settings.max_parallel_upstreams)

    def _base_url(self, service: str) -> str:
        """Resolve one of the fixed, low-cardinality owning-service names."""
        if service == "core":
            return settings.core_url
        if service == "profile":
            return settings.profile_social_url
        if service == "vibes":
            return settings.vibes_url
        raise ValueError(f"Unknown upstream service: {service}")

    async def get_json(
        self,
        service: str,
        path: str,
        *,
        params: dict[str, object] | None = None,
    ) -> object:
        """Read JSON from an owner service and record complete latency/outcome."""
        started = perf_counter()
        outcome = "error"
        url = f"{self._base_url(service)}{path}"
        headers = {
            "Authorization": self._metadata.authorization,
            "X-Request-ID": self._metadata.request_id,
        }
        if self._metadata.traceparent:
            headers["traceparent"] = self._metadata.traceparent

        try:
            try:
                async with self._semaphore:
                    with tracer.start_as_current_span(
                        "graphql.upstream",
                        attributes={
                            "funkey.upstream.service": service,
                            "http.request.method": "GET",
                        },
                    ):
                        response = await self._client.get(
                            url,
                            headers=headers,
                            params=params,
                            timeout=settings.upstream_timeout_seconds,
                        )
            except httpx.TimeoutException as exc:
                raise GraphQLError(
                    f"{service} read timed out",
                    extensions={"code": "UPSTREAM_TIMEOUT", "service": service},
                ) from exc
            except httpx.HTTPError as exc:
                raise GraphQLError(
                    f"{service} read failed",
                    extensions={"code": "UPSTREAM_UNAVAILABLE", "service": service},
                ) from exc

            if response.status_code >= 400:
                code = (
                    "FORBIDDEN"
                    if response.status_code in {401, 403}
                    else "UPSTREAM_ERROR"
                )
                raise GraphQLError(
                    f"{service} returned HTTP {response.status_code}",
                    extensions={
                        "code": code,
                        "service": service,
                        "status": response.status_code,
                    },
                )

            try:
                payload = response.json()
            except ValueError as exc:
                raise GraphQLError(
                    f"{service} returned invalid JSON",
                    extensions={"code": "UPSTREAM_PROTOCOL", "service": service},
                ) from exc

            outcome = "ok"
            return payload
        finally:
            observe_upstream(
                service,
                perf_counter() - started,
                outcome=outcome,
            )
