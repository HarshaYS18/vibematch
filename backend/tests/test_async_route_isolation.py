import inspect
from unittest import TestCase

from app.api.routes import inbox_message_tools, love_bonds
from app.api.routes.wallet import convert_ruby_to_coins, recharge_wallet


class AsyncRouteIsolationTests(TestCase):
    def test_db_heavy_user_routes_run_in_fastapi_threadpool(self):
        routes = [
            recharge_wallet,
            convert_ruby_to_coins,
            love_bonds.send_love_bond_request,
            love_bonds.accept_love_bond_request,
            love_bonds.reject_love_bond_request,
            inbox_message_tools.edit_message_text,
        ]
        for route in routes:
            with self.subTest(route=route.__name__):
                self.assertFalse(
                    inspect.iscoroutinefunction(route),
                    f"{route.__name__} must stay synchronous while it uses sync SQLAlchemy",
                )

    def test_socket_broadcast_helpers_remain_async(self):
        self.assertTrue(inspect.iscoroutinefunction(inbox_message_tools.inbox_ws_manager.broadcast_to_users))
        self.assertTrue(inspect.iscoroutinefunction(love_bonds.inbox_ws_manager.broadcast_to_users))


if __name__ == "__main__":
    import unittest
    unittest.main()
