import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chunk 6 exposes one canonical room media boundary', () {
    final contract = File(
      'lib/room_media/domain/room_media_engine.dart',
    ).readAsStringSync();
    final factory = File(
      'lib/room_media/room_media_engine_factory.dart',
    ).readAsStringSync();
    final nativeEngine = File(
      'lib/room_media/data/native_mediasoup_engine.dart',
    ).readAsStringSync();
    final webEngine = File(
      'lib/room_media/data/web_mediasoup_engine.dart',
    ).readAsStringSync();
    final signaling = File(
      'lib/features/rooms/data/live_room_media_signaling_service.dart',
    ).readAsStringSync();
    final renderer = File(
      'lib/features/rooms/presentation/widgets/live_room_remote_audio_renderers.dart',
    ).readAsStringSync();

    for (final operation in <String>[
      'Future<void> join(',
      'Future<void> leave()',
      'Future<void> publishMic(',
      'Future<void> mute()',
      'Future<void> unmute()',
      'Future<void> consume(',
      'Future<void> reconnect()',
      'Future<void> dispose()',
    ]) {
      expect(contract, contains(operation));
    }

    expect(factory, contains('dart.library.js_interop'));
    expect(nativeEngine, contains('class NativeMediasoupEngine'));
    expect(webEngine, contains('class WebMediasoupEngine'));
    expect(webEngine, contains('real mediasoup/WebRTC'));
    expect(signaling, contains('RoomMediaEngine'));
    expect(signaling, isNot(contains('LiveRoomAudioService')));
    expect(renderer, isNot(contains('LiveRoomAudioService')));
    expect(renderer, isNot(contains('kIsWeb')));
  });

  test('room feature code cannot bypass RoomMediaEngine', () {
    final root = Directory('lib/features/rooms');
    final leaks = <String>[];

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final normalized = entity.path.replaceAll('\\', '/');
      if (normalized.endsWith('/data/live_room_audio_service.dart')) {
        continue;
      }

      final source = entity.readAsStringSync();
      if (source.contains('LiveRoomAudioService')) {
        leaks.add(normalized);
      }
    }

    expect(
      leaks,
      isEmpty,
      reason:
          'Room features must use RoomMediaEngine; concrete mediasoup leaks: '
          '${leaks.join(', ')}',
    );
  });
}
