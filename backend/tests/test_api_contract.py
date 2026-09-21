from __future__ import annotations

import unittest
from collections import defaultdict
from pathlib import Path

from fastapi.routing import APIRoute, APIWebSocketRoute

from app.api.router import api_router


class CanonicalApiContractTests(unittest.TestCase):
    def test_every_registered_endpoint_has_one_owner(self):
        owners = defaultdict(list)
        for route in api_router.routes:
            if isinstance(route, APIRoute):
                for method in sorted(route.methods or set()):
                    if method not in {"HEAD", "OPTIONS"}:
                        owners[(method, route.path)].append(route.name)
            elif isinstance(route, APIWebSocketRoute):
                owners[("WEBSOCKET", route.path)].append(route.name)
        duplicates = {
            f"{method} {path}": names
            for (method, path), names in owners.items()
            if len(names) > 1
        }
        self.assertEqual({}, duplicates, f"Duplicate API registrations found: {duplicates}")

    def test_parallel_legacy_surfaces_are_not_registered(self):
        paths = {route.path for route in api_router.routes}
        self.assertNotIn("/control-center/source-of-truth", paths)
        self.assertNotIn("/rooms/{room_public_id}/realtime-snapshot", paths)
        self.assertFalse(any(path.startswith("/mvp") for path in paths))
        self.assertFalse(any(path.startswith("/internal-test") for path in paths))
        for legacy in {"/users/profile/{public_user_id}", "/users/me/visitors", "/social/users/{target_user_id}/follow", "/economy/users/{user_id}/summary", "/economy/gifts/send-public", "/economy/gifts/send-lucky-public", "/economy/rubies/convert-to-coins", "/experience/rooms/{room_id}"}:
            self.assertNotIn(legacy, paths)

    def test_canonical_routes_exist(self):
        paths = {route.path for route in api_router.routes}
        for expected in {
            "/health", "/app/source-of-truth/master",
            "/families/{family_id}/members",
            "/rooms/{room_public_id}/realtime/snapshot",
            "/ws/room-realtime", "/economy/lucky-packets",
            "/wallet/me", "/economy/gifts/send", "/gifts/catalog", "/store/catalog",
        }:
            self.assertIn(expected, paths)

    def test_route_module_names_do_not_shadow_packages(self):
        root = Path(__file__).resolve().parents[1] / "app" / "api" / "routes"
        conflicts = sorted(
            file.stem for file in root.glob("*.py")
            if file.name != "__init__.py" and (root / file.stem / "__init__.py").exists()
        )
        self.assertEqual([], conflicts, f"Route module/package conflicts: {conflicts}")


if __name__ == "__main__":
    unittest.main()
