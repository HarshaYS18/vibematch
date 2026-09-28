from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class EconomyCallerCutoverTests(unittest.TestCase):
    def test_social_mission_reward_uses_economy_api(self):
        route=(ROOT/"backend/app/api/routes/experience.py").read_text(encoding="utf-8")
        self.assertIn("economy_service_client.claim_mission_reward",route)
        self.assertNotIn("economy_service.credit_social_mission_reward(",route)

    def test_deterministic_mutation_identity_exists(self):
        client=(ROOT/"backend/app/services/economy_service_client.py").read_text(encoding="utf-8")
        self.assertIn("uuid5",client)
        self.assertIn("idempotency_key",client)
        self.assertIn("business_reference",client)

if __name__=="__main__":
    unittest.main()
