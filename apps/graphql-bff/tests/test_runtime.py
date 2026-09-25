import asyncio
import unittest

from dataloader import DataLoader
from operations import OPERATIONS, OPERATIONS_BY_NAME
from schema import schema
from security import inspect_query


class PersistedOperationTests(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
