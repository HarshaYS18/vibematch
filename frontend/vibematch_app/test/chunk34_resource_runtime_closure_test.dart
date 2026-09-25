import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chunk 34 final capture and prefetch closure stays wired', () {
    final bridge = File(
      'lib/features/inbox/data/inbox_call_media_bridge.dart',
    ).readAsStringSync();
    final prefetch = File(
      'lib/foundation/images/app_image_prefetch.dart',
    ).readAsStringSync();
    final gift = File(
      'lib/features/rooms/modules/video_gift/presentation/'
      'clean_video_gift_overlay.dart',
    ).readAsStringSync();

    expect(bridge, contains('CallAudioInputResourceParticipant'));
    expect(bridge, contains('CameraInputResourceParticipant'));
    expect(bridge, contains('_detachAudioInputResource'));
    expect(
      prefetch,
      contains('dependencies: [mediaResourceRegistryProvider]'),
    );
    expect(gift, contains('await _disposeController();'));
  });
}
