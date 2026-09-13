import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock, patch

from fastapi import HTTPException

from app.api.routes import economy


class RoomGiftBroadcastTests(unittest.IsolatedAsyncioTestCase):
    async def test_broadcast_uses_public_room_identity_and_catalog_payload(self):
        sender = SimpleNamespace(
            id=11,
            public_user_id=6418000011,
            display_name="Sender",
            username="sender",
            avatar_url="https://cdn.example/sender.png",
        )
        receiver = SimpleNamespace(
            id=22,
            public_user_id=6418000022,
            display_name="Receiver",
            username="receiver",
            avatar_url="https://cdn.example/receiver.png",
        )
        room = SimpleNamespace(room_public_id="VMGIFT")
        result = {
            "gift_transaction_id": 77,
            "total_coin_value": 1500,
            "lucky_multiplier": 0,
            "lucky_reward_coin_amount": 0,
        }
        gift = {
            "name": "Golden Crown",
            "category": "premium",
            "gift_type": "normal",
            "coin_value": 500,
            "icon_key": "local_workspace_premium",
            "chat_symbol": "👑",
            "asset_url": "https://cdn.example/gifts/crown.webp",
            "video_url": None,
            "asset_path": "assets/gifts/normal/crown.webp",
            "video_asset_path": None,
            "animation_type": "image",
            "version": 3,
            "catalog_version": 9,
            "show_gift_slide": True,
            "show_premium_broadcast": True,
            "show_gift_flight": True,
        }

        broadcast = AsyncMock()
        with (
            patch.object(economy.gift_catalog_service, "find_gift", return_value=gift) as find_gift,
            patch.object(
                economy,
                "_public_wallet_summary",
                return_value={"vip_level": 5, "sent_level": 8, "receive_level": 3},
            ),
            patch.object(economy.room_realtime_connections, "broadcast_room", broadcast),
        ):
            await economy._broadcast_room_gift_event(
                Mock(),
                room=room,
                sender=sender,
                receiver=receiver,
                gift_id="golden_crown",
                coin_value=500,
                quantity=3,
                result=result,
            )

        find_gift.assert_called_once()
        self.assertIsNotNone(find_gift.call_args.kwargs.get("db"))
        broadcast.assert_awaited_once()
        room_id, envelope = broadcast.await_args.args
        self.assertEqual(room_id, "VMGIFT")
        self.assertEqual(envelope["type"], "room/system_event")
        payload = envelope["payload"]
        self.assertEqual(payload["event_type"], "room_gift_sent")
        self.assertEqual(payload["actor_user_id"], "user_6418000011")
        self.assertEqual(payload["target_user_id"], "user_6418000022")
        self.assertEqual(payload["gift_id"], "golden_crown")
        self.assertEqual(payload["quantity"], 3)
        self.assertEqual(payload["total_coin_value"], 1500)
        self.assertEqual(payload["asset_url"], gift["asset_url"])
        self.assertEqual(payload["icon_key"], gift["icon_key"])
        self.assertEqual(payload["chat_symbol"], gift["chat_symbol"])
        self.assertTrue(payload["show_premium_broadcast"])
        self.assertEqual(payload["broadcast_scope"], "room")

    async def test_lucky_broadcast_carries_authoritative_win_fields(self):
        sender = SimpleNamespace(
            id=1,
            public_user_id=7000000001,
            display_name="Lucky Sender",
            username="lucky",
            avatar_url=None,
        )
        receiver = SimpleNamespace(
            id=2,
            public_user_id=7000000002,
            display_name="Lucky Receiver",
            username="receiver",
            avatar_url=None,
        )
        room = SimpleNamespace(room_public_id="LUCKYROOM")
        gift = {
            "name": "Lucky Star",
            "category": "lucky",
            "gift_type": "lucky",
            "coin_value": 100,
            "show_gift_slide": True,
            "show_premium_broadcast": False,
            "show_gift_flight": True,
        }
        result = {
            "gift_transaction_id": 99,
            "total_coin_value": 900,
            "lucky_multiplier": 500,
            "lucky_reward_coin_amount": 450000,
            "lucky_result": {
                "tier": "legendary",
                "display_tier": "legendary",
                "near_miss": False,
                "is_big_win": True,
                "is_broadcast_win": True,
            },
        }
        broadcast = AsyncMock()
        with (
            patch.object(economy.gift_catalog_service, "find_gift", return_value=gift),
            patch.object(economy, "_public_wallet_summary", return_value={}),
            patch.object(economy.room_realtime_connections, "broadcast_room", broadcast),
        ):
            await economy._broadcast_room_gift_event(
                Mock(),
                room=room,
                sender=sender,
                receiver=receiver,
                gift_id="lucky_star",
                coin_value=100,
                quantity=9,
                result=result,
                is_lucky=True,
            )

        payload = broadcast.await_args.args[1]["payload"]
        self.assertTrue(payload["is_lucky"])
        self.assertEqual(payload["lucky_multiplier"], 500)
        self.assertEqual(payload["lucky_reward_coin_amount"], 450000)
        self.assertEqual(payload["lucky_tier"], "legendary")
        self.assertTrue(payload["show_premium_broadcast"])
        self.assertEqual(payload["ribbon_tier"], "premium")


class GiftCatalogValidationTests(unittest.TestCase):
    def test_missing_gift_is_rejected_instead_of_trusting_client_price(self):
        db = Mock()
        with patch.object(economy.gift_catalog_service, "find_gift", return_value=None):
            with self.assertRaises(HTTPException) as raised:
                economy._catalog_gift_or_error(db, "made_up_gift", 1)
        self.assertEqual(raised.exception.status_code, 404)

    def test_lucky_endpoint_rejects_non_lucky_catalog_item(self):
        db = Mock()
        with patch.object(
            economy.gift_catalog_service,
            "find_gift",
            return_value={"gift_type": "normal", "coin_value": 100},
        ):
            with self.assertRaises(HTTPException) as raised:
                economy._catalog_gift_or_error(
                    db,
                    "normal_gift",
                    1,
                    require_lucky=True,
                )
        self.assertEqual(raised.exception.status_code, 400)


if __name__ == "__main__":
    unittest.main()
