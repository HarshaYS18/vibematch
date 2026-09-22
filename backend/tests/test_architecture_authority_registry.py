import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "contracts" / "architecture" / "authorities.yaml"
REQUIRED = {
    "identity.accounts", "identity.sessions", "profiles.public", "rooms.definition",
    "rooms.membership", "rooms.permissions", "rooms.seats", "presence.online_lease",
    "rooms.watch_party", "rooms.activity", "inbox.conversations", "vibes.content",
    "economy.wallet_ledger", "gifts.settlement", "games.catalog_rounds",
    "games.financial_settlement", "missions.progress", "missions.reward_claims",
    "families.membership", "notifications.in_app", "media.metadata", "media.objects",
    "search.index", "analytics.event_stream", "recommendations.ranking",
    "client.room_session_cache",
}

class ArchitectureAuthorityRegistryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.payload = json.loads(REGISTRY.read_text(encoding="utf-8"))
        cls.states = cls.payload["states"]
        cls.by_id = {item["id"]: item for item in cls.states}

    def test_unique_and_required_states(self):
        self.assertEqual(len(self.states), len(self.by_id))
        self.assertTrue(REQUIRED.issubset(self.by_id))

    def test_derived_and_ephemeral_are_reconstructable(self):
        for item in self.states:
            kind = item["classification"]
            self.assertIn(kind, {"AUTHORITY", "PROJECTION", "CACHE", "EPHEMERAL"})
            if kind in {"PROJECTION", "CACHE"}:
                self.assertTrue(item["source_states"], item["id"])
                for source in item["source_states"]:
                    self.assertIn(source, self.by_id, f"{item['id']} -> {source}")
            if kind == "EPHEMERAL":
                self.assertTrue(item["rebuild_from"], item["id"])

    def test_financial_truth_is_economy_owned(self):
        for state_id in (
            "economy.wallet_ledger", "economy.supply_ledger", "gifts.settlement",
            "games.financial_settlement", "missions.reward_claims",
        ):
            item = self.by_id[state_id]
            self.assertEqual("AUTHORITY", item["classification"])
            self.assertEqual("economy", item["logical_owner"])

    def test_transport_projection_client_owners_are_not_durable_authority(self):
        forbidden = {"realtime", "search-projection", "analytics", "recommendation", "flutter"}
        for item in self.states:
            if item["classification"] == "AUTHORITY":
                self.assertNotIn(item["logical_owner"], forbidden, item["id"])

if __name__ == "__main__":
    unittest.main()
