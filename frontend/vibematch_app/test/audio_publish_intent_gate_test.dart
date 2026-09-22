import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/rooms/data/audio_publish_intent_gate.dart';

void main() {
  group('AudioPublishIntentGate', () {
    test('mute invalidates an in-flight publish attempt', () {
      final gate = AudioPublishIntentGate();
      final generation = gate.capture();

      expect(
        gate.isCurrent(generation, seated: true, muted: false),
        isTrue,
      );

      gate.invalidate();

      expect(
        gate.isCurrent(generation, seated: true, muted: false),
        isFalse,
      );
    });

    test('publish intent is invalid while muted or off-seat', () {
      final gate = AudioPublishIntentGate();
      final generation = gate.capture();

      expect(
        gate.isCurrent(generation, seated: true, muted: true),
        isFalse,
      );
      expect(
        gate.isCurrent(generation, seated: false, muted: false),
        isFalse,
      );
    });

    test('new generation can publish after a later unmute', () {
      final gate = AudioPublishIntentGate();
      final stale = gate.capture();
      gate.invalidate();
      final current = gate.capture();

      expect(
        gate.isCurrent(stale, seated: true, muted: false),
        isFalse,
      );
      expect(
        gate.isCurrent(current, seated: true, muted: false),
        isTrue,
      );
    });
  });
}
