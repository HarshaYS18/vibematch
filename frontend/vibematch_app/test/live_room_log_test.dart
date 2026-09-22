import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/rooms/data/live_room_log.dart';

void main() {
  test('normal traces and warnings are quiet by default', () {
    final messages = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() {
      debugPrint = original;
    });

    LiveRoomLog.trace('Media', 'room snapshot payload');
    LiveRoomLog.warning('Audio', 'transient reconnect warning');

    expect(messages, isEmpty);
  });

  test('actionable errors stay visible as one compact line', () {
    final messages = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() {
      debugPrint = original;
    });

    LiveRoomLog.error(
      'Audio',
      'producer failed\nwith a multiline diagnostic payload',
    );

    expect(
      messages,
      contains(
        '[FK:E:Audio] producer failed with a multiline diagnostic payload',
      ),
    );
  });

  test('very long errors are truncated', () {
    final messages = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() {
      debugPrint = original;
    });

    LiveRoomLog.error('Media', 'x' * 400);

    expect(messages, hasLength(1));
    expect(messages.single.length, lessThan(280));
    expect(messages.single.endsWith('…'), isTrue);
  });
}
