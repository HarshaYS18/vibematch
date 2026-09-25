import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chunk 13 performance contracts stay wired', () {
    final shell = File('lib/app/app_shell.dart').readAsStringSync();
    final gate = File('lib/features/vibes/presentation/widgets/vibe_media_playback_gate.dart').readAsStringSync();
    final player = File('lib/features/vibes/presentation/widgets/vibe_media_player.dart').readAsStringSync();
    final network = File('lib/foundation/networking/app_network_client.dart').readAsStringSync();
    final appImage = File('lib/foundation/images/app_image.dart').readAsStringSync();
    final prefetch = File('lib/foundation/images/app_image_prefetch.dart').readAsStringSync();
    final vibeAvatar = File('lib/features/vibes/presentation/widgets/vibe_avatar.dart').readAsStringSync();
    final avatarFrame = File('lib/core/widgets/vm_avatar_frame.dart').readAsStringSync();
    final storyAvatar = File('lib/features/stories/widgets/story_avatar_ring.dart').readAsStringSync();

    expect(shell, contains('_PersistentTabStage'));
    expect(shell, contains('didHaveMemoryPressure'));
    expect(gate, isNot(contains('static final ValueNotifier')));
    expect(player, contains('cacheWidth:'));
    expect(player, contains('_disposeControllerForDistance'));
    expect(network, contains('DeduplicatingAppNetworkClient'));
    expect(appImage, contains('AppImageDecodePolicy'));
    expect(appImage, contains('cacheWidth:'));
    expect(prefetch, contains('MediaResourceKind.imagePrefetch'));
    expect(prefetch, contains('maxConcurrent = 2'));
    expect(prefetch, contains('maxQueued = 12'));
    expect(prefetch, contains('precacheImage'));
    for (final hotSurface in <String>[vibeAvatar, avatarFrame, storyAvatar]) {
      expect(hotSurface, contains('AppImage.network'));
      expect(hotSurface, isNot(contains('Image.network(')));
      expect(hotSurface, isNot(contains('NetworkImage(')));
    }
  });
}
