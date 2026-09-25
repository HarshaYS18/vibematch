import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/rooms/data/live_room_system_event_bus.dart';
import 'package:vibematch_app/features/rooms/presentation/widgets/lucky_win_celebration_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('x100 x500 and x1000 lucky wins render escalating celebrations', (
    tester,
  ) async {
    final events = StreamController<LiveRoomSystemEvent>.broadcast();
    addTearDown(events.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              LuckyWinCelebrationOverlay(systemEvents: events.stream),
            ],
          ),
        ),
      ),
    );

    _publishLuckyWin(events, id: 'lucky-100', multiplier: 100, rewardCoins: 1200);
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byKey(const ValueKey('lucky-win-celebration')), findsOneWidget);
    expect(find.text('BIG WIN'), findsOneWidget);
    expect(find.text('x100'), findsOneWidget);
    expect(find.text('+1.2K COINS'), findsOneWidget);

    // A larger tier preempts a smaller active animation immediately.
    _publishLuckyWin(events, id: 'lucky-500', multiplier: 500, rewardCoins: 15000);
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.text('BIG WIN'), findsNothing);
    expect(find.text('MEGA WIN'), findsOneWidget);
    expect(find.text('x500'), findsOneWidget);

    _publishLuckyWin(events, id: 'lucky-1000', multiplier: 1000, rewardCoins: 250000);
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.text('MEGA WIN'), findsNothing);
    expect(find.text('JACKPOT'), findsOneWidget);
    expect(find.text('x1000'), findsOneWidget);
    expect(find.text('+250K COINS'), findsOneWidget);
  });

  testWidgets('ordinary lucky multipliers do not trigger the celebration', (
    tester,
  ) async {
    final events = StreamController<LiveRoomSystemEvent>.broadcast();
    addTearDown(events.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              LuckyWinCelebrationOverlay(systemEvents: events.stream),
            ],
          ),
        ),
      ),
    );

    _publishLuckyWin(events, id: 'lucky-20', multiplier: 20, rewardCoins: 100);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const ValueKey('lucky-win-celebration')), findsNothing);
    expect(find.text('BIG WIN'), findsNothing);
    expect(find.text('MEGA WIN'), findsNothing);
    expect(find.text('JACKPOT'), findsNothing);
  });

  testWidgets('duplicate authoritative event id is not replayed', (tester) async {
    final events = StreamController<LiveRoomSystemEvent>.broadcast();
    addTearDown(events.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              LuckyWinCelebrationOverlay(systemEvents: events.stream),
            ],
          ),
        ),
      ),
    );

    _publishLuckyWin(events, id: 'same-event', multiplier: 100, rewardCoins: 500);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('BIG WIN'), findsOneWidget);

    // Same backend event arriving again must not restart/queue the effect.
    _publishLuckyWin(events, id: 'same-event', multiplier: 100, rewardCoins: 500);
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const ValueKey('lucky-win-celebration')), findsNothing);
  });
}

void _publishLuckyWin(
  StreamController<LiveRoomSystemEvent> events, {
  required String id,
  required int multiplier,
  required int rewardCoins,
}) {
  events.add(
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
      'lucky_reward_coin_amount': rewardCoins,
      'show_gift_slide': true,
      'show_premium_broadcast': false,
      'show_gift_flight': true,
      'created_at': '2026-09-13T12:00:00Z',
    }),
  );
}
