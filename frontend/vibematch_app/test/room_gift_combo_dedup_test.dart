import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/rooms/data/live_room_system_event_bus.dart';
import 'package:vibematch_app/features/rooms/modules/gift_slide/presentation/gift_slide_overlay.dart';
import 'package:vibematch_app/features/rooms/presentation/live_room_models.dart';
import 'package:vibematch_app/features/rooms/presentation/widgets/live_room_gift_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    LiveRoomSystemEventBus.latestEvent.value = null;
  });

  testWidgets('sender lucky combo backend echo does not create a second slide', (
    tester,
  ) async {
    const localSlide = GiftSlide(
      id: 'local-lucky-slide',
      senderName: 'Sender',
      receiverName: 'Receiver',
      giftName: 'Lucky Star x500',
      giftIcon: Icons.star_rounded,
      colors: <Color>[Colors.amber, Colors.orange],
      combo: 18,
      baseCombo: 9,
      remainingSeconds: 15,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveRoomGiftOverlay(
            slides: const <GiftSlide>[localSlide],
            activeComboSlide: localSlide,
            bottomPadding: 0,
            currentUserId: 'user_7000000001',
            onComboTap: (_) {},
            onComboButtonTap: () {},
            onVideoGiftFinished: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GiftSlideCardModule), findsOneWidget);
    expect(find.text('Combo x18'), findsOneWidget);
    expect(find.text('WIN x500'), findsOneWidget);

    LiveRoomSystemEventBus.publish(
      LiveRoomSystemEvent.fromJson(<String, dynamic>{
        'id': 'gift_combo_2',
        'event_type': 'room_gift_sent',
        'room_id': 'LUCKYROOM',
        'actor_user_id': 'user_7000000001',
        'actor_name': 'Sender',
        'target_user_id': 'user_7000000002',
        'target_name': 'Receiver',
        'gift_id': 'lucky_star',
        'gift_name': 'Lucky Star',
        'gift_type': 'lucky',
        'quantity': 9,
        'coin_value': 100,
        'total_coin_value': 900,
        'is_lucky': true,
        'lucky_multiplier': 100,
        'show_gift_slide': true,
        'show_premium_broadcast': false,
        'show_gift_flight': true,
        'created_at': '2026-09-13T12:00:00Z',
      }),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(GiftSlideCardModule), findsOneWidget);
    expect(find.text('Combo x18'), findsOneWidget);
  });

  testWidgets('receiver lucky combo stays one slide and accumulates quantity', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveRoomGiftOverlay(
            slides: const <GiftSlide>[],
            activeComboSlide: null,
            bottomPadding: 0,
            currentUserId: 'user_7000000002',
            onComboTap: (_) {},
            onComboButtonTap: () {},
            onVideoGiftFinished: (_) {},
          ),
        ),
      ),
    );

    void publishLucky({required String id, required int multiplier}) {
      LiveRoomSystemEventBus.publish(
        LiveRoomSystemEvent.fromJson(<String, dynamic>{
          'id': id,
          'event_type': 'room_gift_sent',
          'room_id': 'LUCKYROOM',
          'actor_user_id': 'user_7000000001',
          'actor_name': 'Sender',
          'target_user_id': 'user_7000000002',
          'target_name': 'Receiver',
          'gift_id': 'crystal_hunt',
          'gift_name': 'Crystal Hunt',
          'gift_type': 'lucky',
          'quantity': 9,
          'coin_value': 89,
          'total_coin_value': 801,
          'is_lucky': true,
          'lucky_multiplier': multiplier,
          'lucky_reward_coin_amount': 1000,
          'show_gift_slide': true,
          'show_premium_broadcast': false,
          'show_gift_flight': true,
          'created_at': '2026-09-13T12:00:00Z',
        }),
      );
    }

    publishLucky(id: 'gift_combo_receiver_1', multiplier: 500);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GiftSlideCardModule), findsOneWidget);
    expect(find.text('Combo x9'), findsOneWidget);
    expect(find.text('WIN x500'), findsOneWidget);

    publishLucky(id: 'gift_combo_receiver_2', multiplier: 100);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(GiftSlideCardModule), findsOneWidget);
    expect(find.text('Combo x18'), findsOneWidget);
    expect(find.text('Combo x9'), findsNothing);
    expect(find.text('WIN x100'), findsOneWidget);
  });
}
