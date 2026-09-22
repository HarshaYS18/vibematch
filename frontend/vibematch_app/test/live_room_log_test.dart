import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/rooms/data/live_room_log.dart';

void main() {
  test('normal live-room traces are quiet by default', () {
    final messages = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() {
      debugPrint = original;
    });

    LiveRoomLog.trace('Media', 'room snapshot payload');
    LiveRoomLog.trace('Audio', 'transport state connected');

    expect(messages, isEmpty);
  });

  test('actionable warnings remain visible in debug tests', () {
    final messages = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() {
      debugPrint = original;
    });

    LiveRoomLog.warning('Audio', 'producer failed');

    expect(messages, contains('[VibeMatchAudio][warn] producer failed'));
  });
}
