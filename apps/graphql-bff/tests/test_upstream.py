"""Owner-service client contract tests for GraphQL composition."""

import unittest

import httpx
from graphql import GraphQLError

from upstream import RequestMetadata, UpstreamClient


class UpstreamClientTests(unittest.IsolatedAsyncioTestCase):
    """Verify propagation and deterministic owner-failure mapping."""

    async def test_get_json_forwards_auth_request_and_trace_context(self):
        captured = {}

        def handler(request: httpx.Request) -> httpx.Response:
            captured["authorization"] = request.headers.get("authorization")
            captured["request_id"] = request.headers.get("x-request-id")
            captured["traceparent"] = request.headers.get("traceparent")
            captured["query"] = request.url.query.decode()
            return httpx.Response(200, json={"ok": True})

        metadata = RequestMetadata(
            authorization="Bearer integration-token",
            request_id="request-123",
            traceparent="00-0123456789abcdef0123456789abcdef-0123456789abcdef-01",
        )
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(handler),
        ) as http:
            client = UpstreamClient(http, metadata)
            payload = await client.get_json(
                "core",
                "/probe",
                params={"limit": 7},
            )

        self.assertEqual(payload, {"ok": True})
        self.assertEqual(captured["authorization"], "Bearer integration-token")
        self.assertEqual(captured["request_id"], "request-123")
        self.assertEqual(captured["traceparent"], metadata.traceparent)
        self.assertEqual(captured["query"], "limit=7")

    async def test_timeout_maps_to_graphql_timeout_error(self):
        def handler(request: httpx.Request) -> httpx.Response:
            raise httpx.ReadTimeout("simulated timeout", request=request)

        metadata = RequestMetadata(
            authorization="Bearer test",
            request_id="request-timeout",
            traceparent=None,
        )
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(handler),
        ) as http:
            client = UpstreamClient(http, metadata)
            with self.assertRaises(GraphQLError) as raised:
                await client.get_json("core", "/probe")

        self.assertEqual(raised.exception.extensions["code"], "UPSTREAM_TIMEOUT")
        self.assertEqual(raised.exception.extensions["service"], "core")

    async def test_owner_auth_failure_maps_to_forbidden(self):
        def handler(_request: httpx.Request) -> httpx.Response:
            return httpx.Response(401, json={"detail": "unauthorized"})

        metadata = RequestMetadata(
            authorization="Bearer rejected",
            request_id="request-auth",
            traceparent=None,
        )
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(handler),
        ) as http:
            client = UpstreamClient(http, metadata)
            with self.assertRaises(GraphQLError) as raised:
                await client.get_json("profile", "/probe")

        self.assertEqual(raised.exception.extensions["code"], "FORBIDDEN")
        self.assertEqual(raised.exception.extensions["status"], 401)

    async def test_invalid_owner_json_maps_to_protocol_error(self):
        def handler(_request: httpx.Request) -> httpx.Response:
            return httpx.Response(
                200,
                content=b"not-json",
                headers={"content-type": "application/json"},
            )

        metadata = RequestMetadata(
            authorization="Bearer test",
            request_id="request-protocol",
            traceparent=None,
        )
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(handler),
        ) as http:
            client = UpstreamClient(http, metadata)
            with self.assertRaises(GraphQLError) as raised:
                await client.get_json("vibes", "/probe")

        self.assertEqual(raised.exception.extensions["code"], "UPSTREAM_PROTOCOL")
        self.assertEqual(raised.exception.extensions["service"], "vibes")


if __name__ == "__main__":
    unittest.main()
