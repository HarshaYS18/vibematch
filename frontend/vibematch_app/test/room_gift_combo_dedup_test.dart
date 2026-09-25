import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/rooms/data/live_room_system_event_bus.dart';
import 'package:vibematch_app/features/rooms/modules/gift_slide/presentation/gift_slide_overlay.dart';
import 'package:vibematch_app/features/rooms/presentation/live_room_models.dart';
import 'package:vibematch_app/features/rooms/presentation/widgets/live_room_gift_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  StreamController<LiveRoomSystemEvent> eventController() {
    final controller = StreamController<LiveRoomSystemEvent>.broadcast();
    addTearDown(controller.close);
    return controller;
  }

  LiveRoomSystemEvent luckyEvent({
    required String id,
    required int multiplier,
    String giftId = 'lucky_star',
    String giftName = 'Lucky Star',
    int coinValue = 100,
  }) {
    return LiveRoomSystemEvent.fromJson(<String, dynamic>{
      'id': id,
      'event_type': 'room_gift_sent',
      'room_id': 'LUCKYROOM',
      'actor_user_id': 'user_7000000001',
      'actor_name': 'Sender',
      'target_user_id': 'user_7000000002',
      'target_name': 'Receiver',
      'gift_id': giftId,
      'gift_name': giftName,
      'gift_type': 'lucky',
      'quantity': 9,
      'coin_value': coinValue,
      'total_coin_value': coinValue * 9,
      'is_lucky': true,
      'lucky_multiplier': multiplier,
      'lucky_reward_coin_amount': 1000,
      'show_gift_slide': true,
      'show_premium_broadcast': false,
      'show_gift_flight': true,
      'created_at': '2026-09-13T12:00:00Z',
    });
  }

  testWidgets('sender lucky combo backend echo does not create a second slide', (
    tester,
  ) async {
    final events = eventController();
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
            systemEvents: events.stream,
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

    events.add(
      luckyEvent(id: 'gift_combo_2', multiplier: 100),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(GiftSlideCardModule), findsOneWidget);
    expect(find.text('Combo x18'), findsOneWidget);
    expect(find.text('WIN x100'), findsOneWidget);
    expect(find.text('WIN x500'), findsNothing);
  });

  testWidgets('sender backend echo arriving before local slide never flashes duplicate', (
    tester,
  ) async {
    final events = eventController();
    Widget overlay(List<GiftSlide> slides, GiftSlide? active) {
      return MaterialApp(
        home: Scaffold(
          body: LiveRoomGiftOverlay(
            systemEvents: events.stream,
            slides: slides,
            activeComboSlide: active,
            bottomPadding: 0,
            currentUserId: 'user_7000000001',
            onComboTap: (_) {},
            onComboButtonTap: () {},
            onVideoGiftFinished: (_) {},
          ),
        ),
      );
    }

    await tester.pumpWidget(overlay(const <GiftSlide>[], null));
    events.add(
      luckyEvent(id: 'gift_before_http_response', multiplier: 500),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(GiftSlideCardModule), findsNothing);

    const committed = GiftSlide(
      id: 'local-after-http',
      senderName: 'Sender',
      receiverName: 'Receiver',
      giftName: 'Lucky Star x1',
      giftIcon: Icons.star_rounded,
      colors: <Color>[Colors.amber, Colors.orange],
      combo: 9,
      baseCombo: 9,
      remainingSeconds: 15,
    );
    await tester.pumpWidget(overlay(const <GiftSlide>[committed], committed));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(GiftSlideCardModule), findsOneWidget);
    expect(find.text('Combo x9'), findsOneWidget);
    expect(find.text('WIN x500'), findsOneWidget);
  });

  testWidgets('receiver lucky combo stays one slide and accumulates quantity', (
    tester,
  ) async {
    final events = eventController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveRoomGiftOverlay(
            systemEvents: events.stream,
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

    events.add(
      luckyEvent(
        id: 'gift_combo_receiver_1',
        multiplier: 500,
        giftId: 'crystal_hunt',
        giftName: 'Crystal Hunt',
        coinValue: 89,
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GiftSlideCardModule), findsOneWidget);
    expect(find.text('Combo x9'), findsOneWidget);
    expect(find.text('WIN x500'), findsOneWidget);

    events.add(
      luckyEvent(
        id: 'gift_combo_receiver_2',
        multiplier: 100,
        giftId: 'crystal_hunt',
        giftName: 'Crystal Hunt',
        coinValue: 89,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(GiftSlideCardModule), findsOneWidget);
    expect(find.text('Combo x18'), findsOneWidget);
    expect(find.text('Combo x9'), findsNothing);
    expect(find.text('WIN x100'), findsOneWidget);
  });

  testWidgets('zero multiplier is shown as try again without resetting combo', (
    tester,
  ) async {
    final events = eventController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveRoomGiftOverlay(
            systemEvents: events.stream,
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

    events.add(
      luckyEvent(id: 'try_again_1', multiplier: 100),
    );
    await tester.pump(const Duration(milliseconds: 300));
    events.add(
      luckyEvent(id: 'try_again_2', multiplier: 0),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(GiftSlideCardModule), findsOneWidget);
    expect(find.text('Combo x18'), findsOneWidget);
    expect(find.text('TRY AGAIN'), findsOneWidget);
  });
}
