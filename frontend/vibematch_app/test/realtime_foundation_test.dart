import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/foundation/realtime/realtime_event_envelope.dart';

void main() {
  RealtimeEventEnvelope event(int sequence) {
    return RealtimeEventEnvelope.fromJson(<String, dynamic>{
      'eventId': 'event-$sequence',
      'sequence': sequence,
      'stream': 'app:user:42',
      'type': 'inbox_message_created',
      'serverTime': '2026-09-22T12:00:00Z',
      'payload': <String, dynamic>{'value': sequence},
    });
  }

  test('cursor accepts ordered events and ignores duplicates', () {
    final cursor = RealtimeStreamCursor();

    expect(cursor.accept(event(10)), RealtimeSequenceDecision.accepted);
    expect(cursor.accept(event(11)), RealtimeSequenceDecision.accepted);
    expect(cursor.accept(event(11)), RealtimeSequenceDecision.duplicate);
    expect(cursor.lastSequence('app:user:42'), 11);
  });

  test('cursor detects a gap and only advances after reconciliation', () {
    final cursor = RealtimeStreamCursor();

    cursor.accept(event(20));
    final missing = event(24);

    expect(cursor.accept(missing), RealtimeSequenceDecision.gap);
    final gap = cursor.gapFor(missing);
    expect(gap.expectedSequence, 21);
    expect(gap.observedSequence, 24);
    expect(cursor.lastSequence('app:user:42'), 20);

    cursor.markResynced(gap.stream, gap.observedSequence);
    expect(cursor.accept(event(25)), RealtimeSequenceDecision.accepted);
  });

  test('legacy event shape remains consumable during migration', () {
    final envelope = RealtimeEventEnvelope.fromJson(<String, dynamic>{
      'event': 'inbox_typing_start',
      'conversation_id': 'abc',
      'user_id': 5,
    });

    expect(envelope.sequence, 0);
    expect(envelope.type, 'inbox_typing_start');
    expect(envelope.toLegacyEvent()['conversation_id'], 'abc');
  });
}
