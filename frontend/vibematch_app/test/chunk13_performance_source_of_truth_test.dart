import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chunk 13 performance contracts stay wired', () {
    final shell = File('lib/app/app_shell.dart').readAsStringSync();
    final gate = File('lib/features/vibes/presentation/widgets/vibe_media_playback_gate.dart').readAsStringSync();
    final player = File('lib/features/vibes/presentation/widgets/vibe_media_player.dart').readAsStringSync();
    final network = File('lib/foundation/networking/app_network_client.dart').readAsStringSync();
    final appImage = File('lib/foundation/images/app_image.dart').readAsStringSync();
    final vibeAvatar = File('lib/features/vibes/presentation/widgets/vibe_avatar.dart').readAsStringSync();
    final avatarFrame = File('lib/core/widgets/vm_avatar_frame.dart').readAsStringSync();

    expect(shell, contains('_PersistentTabStage'));
    expect(shell, contains('didHaveMemoryPressure'));
    expect(gate, isNot(contains('static final ValueNotifier')));
    expect(player, contains('cacheWidth:'));
    expect(player, contains('_disposeControllerForDistance'));
    expect(network, contains('DeduplicatingAppNetworkClient'));
    expect(appImage, contains('AppImageDecodePolicy'));
    expect(appImage, contains('cacheWidth:'));
    for (final hotSurface in <String>[vibeAvatar, avatarFrame]) {
      expect(hotSurface, contains('AppImage.network'));
      final rawSurface = hotSurface.replaceAll('AppImage.network(', '');
      expect(rawSurface, isNot(contains('Image.network(')));
      expect(rawSurface, isNot(contains('NetworkImage(')));
    }
  });
}
