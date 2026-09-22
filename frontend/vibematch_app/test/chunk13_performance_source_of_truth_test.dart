import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chunk 13 performance contracts stay wired', () {
    final shell = File('lib/app/app_shell.dart').readAsStringSync();
    final gate = File('lib/features/vibes/presentation/widgets/vibe_media_playback_gate.dart').readAsStringSync();
    final player = File('lib/features/vibes/presentation/widgets/vibe_media_player.dart').readAsStringSync();
    final network = File('lib/foundation/networking/app_network_client.dart').readAsStringSync();

    expect(shell, contains('_PersistentTabStage'));
    expect(shell, contains('didHaveMemoryPressure'));
    expect(gate, isNot(contains('static final ValueNotifier')));
    expect(player, contains('cacheWidth:'));
    expect(player, contains('_disposeControllerForDistance'));
    expect(network, contains('DeduplicatingAppNetworkClient'));
  });
}
