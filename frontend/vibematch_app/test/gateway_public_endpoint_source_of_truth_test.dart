import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/core/network/vm_api_config.dart';

void main() {
  test('Chunk 35 exposes only canonical production public edge origins', () {
    expect(VmApiConfig.productionApiOrigin, 'https://api.funkey.com');
    expect(
      VmApiConfig.productionRealtimeWebSocketUrl,
      'wss://realtime.funkey.com/ws',
    );
    expect(VmApiConfig.productionMediaOrigin, 'https://media.funkey.com');
    expect(VmApiConfig.productionCdnOrigin, 'https://cdn.funkey.com');
  });

  test('Flutter source cannot contain Kubernetes internal service discovery', () {
    final lib = Directory('lib');
    final forbidden = <String>[
      '.svc.cluster.local',
      'http://funkey-api:',
      'http://funkey-inbox:',
      'http://funkey-vibes:',
      'http://funkey-room-control:',
      'http://funkey-realtime:',
    ];

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final marker in forbidden) {
        expect(
          source,
          isNot(contains(marker)),
          reason: '${entity.path} must not contain internal endpoint $marker',
        );
      }
    }
  });
}
