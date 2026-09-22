import unittest

from fastapi.routing import APIRoute

from app.api.routes.families import router


class FamilyCommunityContractTests(unittest.TestCase):
    def test_family_chat_uses_existing_family_and_inbox_domains(self):
        routes = {
            (route.path, method)
            for route in router.routes
            if isinstance(route, APIRoute)
            for method in route.methods
        }
        self.assertIn(("/families/{family_id}/chat", "GET"), routes)
        self.assertIn(("/families/{family_id}/chat/messages", "POST"), routes)


if __name__ == "__main__":
    unittest.main()
