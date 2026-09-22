import inspect
from unittest import TestCase

from app.api.routes import (
    economy,
    economy_admin,
    inbox,
    inbox_calls,
    inbox_message_tools,
    inbox_preferences,
    love_bonds,
    lucky_packets,
)
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
            economy.send_gift,
            economy._send_lucky_gift_authoritative,
            inbox.send_message,
            inbox.update_message,
            inbox.delete_message,
            inbox.update_secret_drift,
            inbox.close_secret_drift_session,
            inbox.create_report,
            inbox.reject_report,
            inbox.accept_report,
            inbox.monitor_action,
            lucky_packets.create_lucky_packet,
            lucky_packets.get_active_lucky_packet,
            lucky_packets.get_lucky_packet,
            lucky_packets.claim_lucky_packet,
            lucky_packets.finalize_lucky_packet,
            inbox_calls.start_call,
            inbox_calls.accept_call,
            inbox_calls.decline_call,
            inbox_calls.end_call,
            inbox_calls.mark_missed_call,
            inbox_preferences.update_conversation_theme,
            economy_admin.official_recharge_wallet,
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
        self.assertTrue(inspect.iscoroutinefunction(inbox.inbox_ws_manager.broadcast_to_users))
        self.assertTrue(inspect.iscoroutinefunction(economy.room_realtime_connections.broadcast_room))
        self.assertTrue(inspect.iscoroutinefunction(lucky_packets.room_realtime_connections.broadcast_room))
        self.assertTrue(inspect.iscoroutinefunction(inbox_calls.inbox_ws_manager.send_to_user))
        self.assertTrue(inspect.iscoroutinefunction(inbox_preferences.inbox_ws_manager.send_to_user))
        self.assertTrue(inspect.iscoroutinefunction(economy_admin.inbox_ws_manager.send_to_user))


if __name__ == "__main__":
    import unittest
    unittest.main()
