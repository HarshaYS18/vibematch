import unittest

from app.services.lucky_packet_service import _build_allocations


class LuckyPacketAllocationTests(unittest.TestCase):
    def test_allocations_conserve_total(self):
        allocations = _build_allocations(5000, 20)
        self.assertEqual(len(allocations), 20)
        self.assertTrue(all(value > 0 for value in allocations))
        self.assertEqual(sum(allocations), 5000)

    def test_allocations_require_enough_coins(self):
        with self.assertRaises(ValueError):
            _build_allocations(4, 5)


if __name__ == "__main__":
    unittest.main()
