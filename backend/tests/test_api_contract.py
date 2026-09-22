from __future__ import annotations

import unittest
from collections import defaultdict
from pathlib import Path

from fastapi.routing import APIRoute, APIWebSocketRoute

from app.api.router import api_router
from app.services import app_source_registry_service


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
        paths = {route.path.removeprefix("/api/v1") for route in api_router.routes}
        self.assertNotIn("/control-center/source-of-truth", paths)
        self.assertNotIn("/rooms/{room_public_id}/realtime-snapshot", paths)
        self.assertFalse(any(path.startswith("/mvp") for path in paths))
        self.assertFalse(any(path.startswith("/internal-test") for path in paths))
        for legacy in {"/users/profile/{public_user_id}", "/users/me/visitors", "/social/users/{target_user_id}/follow", "/economy/users/{user_id}/summary", "/economy/gifts/send-public", "/economy/gifts/send-lucky-public", "/economy/rubies/convert-to-coins", "/experience/rooms/{room_id}", "/wallet/ruby/convert"}:
            self.assertNotIn(legacy, paths)

    def test_canonical_routes_exist(self):
        paths = {route.path.removeprefix("/api/v1") for route in api_router.routes}
        for expected in {
            "/health", "/app/source-of-truth/master",
            "/families/{family_id}/members",
            "/rooms/{room_public_id}/realtime/snapshot",
            "/ws/room-realtime", "/lucky-packets", "/lucky-packets/active",
            "/admin/games/pools", "/admin/games/props/jungle-hunt",
            "/admin/games/seed-defaults", "/admin/games/catalog/{game_key}",
            "/rooms/{room_public_id}/media", "/admin/media/nodes", "/support/tickets",
            "/wallets/me", "/wallets/rubies/convert", "/wallets/rubies/withdraw", "/economy/gifts/send", "/gifts/catalog", "/store/catalog",
        }:
            self.assertIn(expected, paths)

    def test_main_shell_source_registry_uses_registered_canonical_routes(self):
        registry = app_source_registry_service.get_app_source_registry()
        registered_paths = {
            route.path.removeprefix("/api/v1")
            for route in api_router.routes
            if isinstance(route, APIRoute)
        }

        self.assertEqual("/users/me/master-state", registry.master_api.path)

        by_key = {item.tab_key: item for item in registry.tabs}
        for tab_key in {"home", "vibes", "inbox", "profile"}:
            self.assertIn(tab_key, by_key)
            self.assertEqual(
                "/users/me/master-state",
                by_key[tab_key].master_read,
            )

        expected_main_shell_reads = {
            "/home-banners",
            "/vibes/feed",
            "/rooms/trending",
            "/inbox/conversations",
            "/inbox/lock/status",
            "/inbox/backup/status",
            "/profile-display/me",
            "/profile-display/users/{public_user_id}",
            "/users/{public_user_id}",
            "/users/me/profile-visitors",
        }
        self.assertTrue(
            expected_main_shell_reads.issubset(registered_paths),
            expected_main_shell_reads - registered_paths,
        )

        profile_reads = {
            endpoint.path for endpoint in by_key["profile"].child_reads
        }
        self.assertIn("/users/{public_user_id}", profile_reads)
        self.assertIn("/users/me/profile-visitors", profile_reads)

        room_reads = {
            endpoint.path for endpoint in by_key["rooms"].child_reads
        }
        self.assertIn(
            "/rooms/{room_public_id}/realtime/snapshot",
            room_reads,
        )

    def test_retired_admin_and_economy_prefixes_are_absent(self):
        retired = ("/super-owner", "/control-center", "/games/admin", "/economy/admin", "/economy/lucky-packets", "/wallet/", "/moderation/")
        for route in api_router.routes:
            self.assertTrue(route.path.startswith("/api/v1/"))
            self.assertFalse(route.path.removeprefix("/api/v1").startswith(retired), route.path)

    def test_route_module_names_do_not_shadow_packages(self):
        root = Path(__file__).resolve().parents[1] / "app" / "api" / "routes"
        conflicts = sorted(
            file.stem for file in root.glob("*.py")
            if file.name != "__init__.py" and (root / file.stem / "__init__.py").exists()
        )
        self.assertEqual([], conflicts, f"Route module/package conflicts: {conflicts}")


if __name__ == "__main__":
    unittest.main()
