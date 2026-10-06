import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('room media discovery uses dedicated Chunk 35 media-control endpoint', () {
    final config = File('lib/core/network/vm_api_config.dart').readAsStringSync();
    final audio = File(
      'lib/features/rooms/data/live_room_audio_service.dart',
    ).readAsStringSync();

    expect(config, contains('static String mediaControlEndpoint'));
    expect(config, contains(r'$mediaControlOrigin$apiPrefix/media-control'));
    expect(audio, contains('VmApiConfig.mediaControlEndpoint'));
    expect(audio, contains('/assignment'));
    expect(
      audio,
      isNot(contains("VmApiConfig.endpoint('/rooms/")),
    );
  });
}
