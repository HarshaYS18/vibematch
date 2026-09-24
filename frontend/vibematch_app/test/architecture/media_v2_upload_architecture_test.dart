import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current.path.endsWith('vibematch_app')
      ? Directory.current
      : Directory('frontend/vibematch_app');

  String read(String relative) =>
      File('${root.path}/$relative').readAsStringSync();

  test('Media v2 upload transport is streamed from foundation', () {
    final api = read('lib/features/media/data/media_upload_api_service.dart');
    final transport =
        read('lib/foundation/networking/direct_upload_transport.dart');

    expect(api, contains('ApiClientNetworkAdapter'));
    expect(api, contains('StreamingUploadSource'));
    expect(api, isNot(contains('MultipartRequest')));
    expect(transport, contains('http.StreamedRequest'));
    expect(transport, contains('openRange(start, endExclusive)'));
  });

  test('large video and room music paths avoid whole-file reads', () {
    final vibe = read(
      'lib/features/vibes/presentation/pages/create_vibe_page_modular.dart',
    );
    final room = read('lib/features/rooms/data/room_music_controller.dart');

    expect(vibe, contains('final size = await picked.length()'));
    expect(vibe, contains('sourceType == VibeMediaType.photo'));
    expect(room, contains('uploadRoomMusicXFile'));
    expect(room, isNot(contains('XFile(track.path).readAsBytes()')));
  });

  test('client waits for processing and moderation terminal state', () {
    final api = read('lib/features/media/data/media_upload_api_service.dart');

    expect(api, contains('_waitUntilUsable'));
    expect(api, contains("current.uploadStatus == 'approved'"));
    expect(api, contains('human_review_required'));
    expect(api, contains('Duration(minutes: 6)'));
  });

  test('manual crop encoding runs through compute', () {
    final service = read('lib/features/media/data/media_upload_service.dart');

    expect(
      service,
      contains('compute<Map<String, Object>, Uint8List>'),
    );
    expect(service, contains('_manualCropJpegJob'));
    expect(service, isNot(contains('http.MultipartRequest')));
  });
}
