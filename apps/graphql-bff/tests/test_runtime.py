"""Runtime invariants for persisted GraphQL execution, batching, and telemetry."""

import asyncio
import unittest

from graphql import GraphQLError

from context import GraphQLRequestContext
from dataloader import DataLoader
from metrics import observe_operation, observe_upstream, render
from operations import OPERATIONS, OPERATIONS_BY_NAME
from schema import _filter_home_banners, schema
from security import inspect_query
from upstream import RequestMetadata


class PersistedOperationTests(unittest.TestCase):
    """Validate the immutable persisted read registry and security budgets."""

    def test_four_allowlisted_read_operations_are_safe(self):
        self.assertEqual(
            set(OPERATIONS_BY_NAME),
            {
                "HomeComposite",
                "ProfileComposite",
                "DiscoveryComposite",
                "CreatorAdminDashboard",
            },
        )
        self.assertIsNone(schema.mutation_type)
        for operation in OPERATIONS.values():
            budget = inspect_query(operation.document)
            self.assertLessEqual(budget.depth, 4)
            self.assertLessEqual(budget.complexity, 30)

    def test_operation_ids_are_sha256(self):
        for operation_id in OPERATIONS:
            self.assertEqual(len(operation_id), 64)
            int(operation_id, 16)


class DataLoaderTests(unittest.IsolatedAsyncioTestCase):
    """Validate request-scoped deduplication without cross-request cache state."""

    async def test_duplicate_key_is_loaded_once(self):
        batches = []

        async def batch(keys):
            batches.append(list(keys))
            return {key: f"value:{key}" for key in keys}

        loader = DataLoader(batch)
        first, second = await asyncio.gather(
            loader.load("user-1"),
            loader.load("user-1"),
        )
        self.assertEqual(first, "value:user-1")
        self.assertEqual(second, "value:user-1")
        self.assertEqual(batches, [["user-1"]])


class HomeCompositionTests(unittest.IsolatedAsyncioTestCase):
    """Ensure Home banner sibling fields share one authoritative owner read."""

    async def test_home_banner_loader_deduplicates_owner_read(self):
        class FakeUpstream:
            def __init__(self):
                self.calls = []

            async def get_json(self, service, path, *, params=None):
                self.calls.append((service, path, params))
                return [
                    {"placement": "event", "title": "Event"},
                    {"placement": "policy_rules", "title": "Rules"},
                ]

        upstream = FakeUpstream()
        metadata = RequestMetadata(
            authorization="Bearer test",
            request_id="test-request",
            traceparent=None,
        )
        context = GraphQLRequestContext.build(upstream, metadata)  # type: ignore[arg-type]

        first, second = await asyncio.gather(
            context.home_banners_loader.load("active"),
            context.home_banners_loader.load("active"),
        )

        self.assertEqual(first, second)
        self.assertEqual(upstream.calls, [("core", "/home-banners", None)])

    async def test_home_banner_partition_preserves_requested_placement(self):
        payload = [
            {"placement": "event", "title": "Event A"},
            {"placement": "policy_rules", "title": "Rules"},
            {"placement": "event", "title": "Event B"},
            "invalid",
        ]

        self.assertEqual(
            [item["title"] for item in _filter_home_banners(payload, "event")],
            ["Event A", "Event B"],
        )
        self.assertEqual(
            [item["title"] for item in _filter_home_banners(payload, "policy_rules")],
            ["Rules"],
        )
        with self.assertRaises(GraphQLError):
            _filter_home_banners({"not": "a-list"}, "event")
        with self.assertRaises(GraphQLError):
            _filter_home_banners(["invalid-item"], "event")


class MetricsTests(unittest.TestCase):
    """Verify bounded-cardinality latency histograms remain queryable."""

    def test_operation_and_upstream_histograms_render(self):
        observe_operation("HomeComposite", 0.08, outcome="ok")
        observe_upstream("core", 0.04, outcome="ok")

        payload = render()

        self.assertIn(
            'funkey_graphql_operation_duration_seconds_bucket{operation="HomeComposite",outcome="ok",le="0.1"}',
            payload,
        )
        self.assertIn(
            'funkey_graphql_operation_duration_seconds_count{operation="HomeComposite",outcome="ok"}',
            payload,
        )
        self.assertIn(
            'funkey_graphql_upstream_duration_seconds_bucket{service="core",outcome="ok",le="0.05"}',
            payload,
        )
        self.assertIn(
            'funkey_graphql_upstream_duration_seconds_count{service="core",outcome="ok"}',
            payload,
        )


if __name__ == "__main__":
    unittest.main()
