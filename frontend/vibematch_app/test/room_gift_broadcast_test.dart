// Regression coverage for room-scoped premium gift presentation queues.
// Each test owns and disposes its queue, matching LiveRoomGiftController
// lifecycle and preventing cross-room/cross-test presentation leakage.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/rooms/data/live_room_system_event_bus.dart';
import 'package:vibematch_app/features/rooms/presentation/widgets/premium_gift_broadcast_overlay.dart';

void main() {
  PremiumGiftBroadcastBus scopedBus() {
    final bus = PremiumGiftBroadcastBus();
    addTearDown(bus.dispose);
    return bus;
  }

  group('room gift realtime payload', () {
    test('parses authoritative send and receive broadcast fields', () {
      final event = LiveRoomSystemEvent.fromJson(<String, dynamic>{
        'id': 'gift_77_6418000022',
        'event_type': 'room_gift_sent',
        'room_id': 'VMGIFT',
        'actor_user_id': 'user_6418000011',
        'actor_name': 'Sender',
        'actor_avatar_url': 'https://cdn.example/sender.png',
        'actor_vip_level': 5,
        'actor_sending_level': 8,
        'actor_receiving_level': 3,
        'target_user_id': 'user_6418000022',
        'target_name': 'Receiver',
        'gift_id': 'golden_crown',
        'gift_name': 'Golden Crown',
        'gift_category': 'premium',
        'gift_type': 'normal',
        'quantity': 3,
        'coin_value': 500,
        'total_coin_value': 1500,
        'asset_url': 'https://cdn.example/gifts/crown.webp',
        'animation_type': 'image',
        'gift_version': 3,
        'catalog_version': 9,
        'show_gift_slide': true,
        'show_premium_broadcast': true,
        'show_gift_flight': true,
        'broadcast_scope': 'room',
        'created_at': '2026-09-13T10:00:00Z',
      });

      expect(event.isRoomGiftSent, isTrue);
      expect(event.actorUserId, 'user_6418000011');
      expect(event.targetUserId, 'user_6418000022');
      expect(event.actorName, 'Sender');
      expect(event.targetName, 'Receiver');
      expect(event.giftId, 'golden_crown');
      expect(event.giftName, 'Golden Crown');
      expect(event.giftQuantity, 3);
      expect(event.giftCoinValue, 500);
      expect(event.giftTotalCoinValue, 1500);
      expect(event.giftAssetUrl, 'https://cdn.example/gifts/crown.webp');
      expect(event.showGiftSlide, isTrue);
      expect(event.showPremiumBroadcast, isTrue);
      expect(event.showGiftFlight, isTrue);
      expect(event.actorVipLevel, 5);
      expect(event.actorSendingLevel, 8);
      expect(event.actorReceivingLevel, 3);
    });

    test('parses lucky win broadcast fields', () {
      final event = LiveRoomSystemEvent.fromJson(<String, dynamic>{
        'id': 'gift_99_7000000002',
        'type': 'room_gift_sent',
        'room_id': 'LUCKYROOM',
        'actor_user_id': 'user_7000000001',
        'target_user_id': 'user_7000000002',
        'gift_id': 'lucky_star',
        'gift_name': 'Lucky Star',
        'gift_type': 'lucky',
        'quantity': 9,
        'coin_value': 100,
        'total_coin_value': 900,
        'is_lucky': true,
        'lucky_multiplier': 500,
        'lucky_reward_coin_amount': 450000,
        'ribbon_tier': 'premium',
        'show_premium_broadcast': true,
      });

      expect(event.isLuckyGift, isTrue);
      expect(event.luckyMultiplier, 500);
      expect(event.luckyRewardCoinAmount, 450000);
      expect(event.ribbonTier, 'premium');
      expect(event.showPremiumBroadcast, isTrue);
    });
  });

  group('premium gift broadcast queue', () {
    test('authoritative backend event wins over sender local echo', () {
      final bus = scopedBus();
      const backend = PremiumGiftBroadcastEvent(
        id: 'premium-gift_77_6418000022',
        senderName: 'Sender',
        targetName: 'Receiver',
        giftName: 'Golden Crown',
        combo: 3,
      );
      const localEcho = PremiumGiftBroadcastEvent(
        id: 'premium-golden_crown-12345',
        senderName: 'Sender',
        targetName: 'Receiver',
        giftName: 'Golden Crown',
        combo: 3,
      );

      bus.publish(backend);
      bus.publish(localEcho);

      expect(bus.active?.id, backend.id);
    });

    test('separate backend transactions are still queued', () {
      final bus = scopedBus();
      const first = PremiumGiftBroadcastEvent(
        id: 'premium-gift_77_6418000022',
        senderName: 'Sender',
        targetName: 'Receiver',
        giftName: 'Golden Crown',
        combo: 3,
      );
      const second = PremiumGiftBroadcastEvent(
        id: 'premium-gift_78_6418000022',
        senderName: 'Sender',
        targetName: 'Receiver',
        giftName: 'Golden Crown',
        combo: 3,
      );

      bus.publish(first);
      bus.publish(second);
      expect(bus.active?.id, first.id);

      bus.completeActive();
      expect(bus.active?.id, second.id);
    });
  });

  testWidgets('premium overlay renders server sender and receiver names', (
    tester,
  ) async {
    final bus = scopedBus();
    bus.publish(
      const PremiumGiftBroadcastEvent(
        id: 'premium-gift_88_6418000022',
        senderName: 'Alice',
        targetName: 'Bob',
        giftName: 'Crown',
        combo: 2,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[PremiumGiftBroadcastOverlay(bus: bus)],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('sent Crown to Bob x2'), findsOneWidget);
  });
}
