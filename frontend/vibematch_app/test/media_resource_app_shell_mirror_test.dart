import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chunk 34 AppShell resource-runtime source contract.
///
/// M2 established the lifecycle mirror, M3 migrated Vibes decoder lifecycle,
/// and M4 migrates verified game-bundle cache cleanup. Image cleanup remains
/// direct until its own micro-chunk.
void main() {
  test('AppShell keeps the resource coordinator session-scoped and alive', () {
    final shell = File('lib/app/app_shell.dart').readAsStringSync();

    expect(
      shell,
      contains("import 'runtime/media_resource_coordinator.dart';"),
    );
    expect(shell, contains('ref.watch(mediaResourceCoordinatorProvider);'));
  });

  test('AppShell mirrors lifecycle and memory pressure into the coordinator', () {
    final shell = File('lib/app/app_shell.dart').readAsStringSync();

    expect(shell, contains('unawaited(_notifyResourceMemoryPressure());'));
    expect(
      shell,
      contains(
        '_notifyResourceForegroundState(state == AppLifecycleState.resumed)',
      ),
    );
    expect(
      shell,
      contains(
        'ref.read(mediaResourceCoordinatorProvider).handleMemoryPressure()',
      ),
    );
    expect(shell, contains('.setForeground(isForeground)'));
  });

  test('M4 migrates Vibes and game cache while preserving image cleanup', () {
    final shell = File('lib/app/app_shell.dart').readAsStringSync();

    expect(
      shell,
      contains('resourceCoordinator.register(_vibesMediaResourceParticipant)'),
    );
    expect(
      shell,
      contains(
        'resourceCoordinator.register(_gameBundleCacheResourceParticipant)',
      ),
    );
    expect(shell, isNot(contains('_vibePlaybackGate.handleMemoryPressure();')));
    expect(shell, isNot(contains('ref.read(gameBundleCacheProvider).clear();')));
    expect(
      shell,
      contains('PaintingBinding.instance.imageCache.clearLiveImages();'),
    );
    expect(shell, contains('unawaited(_reconcileCanonicalShellState());'));
  });

  test('resource lifecycle forwarding is failure-isolated', () {
    final shell = File('lib/app/app_shell.dart').readAsStringSync();

    expect(shell, contains("debugPrint('[FK:W:ResourceRuntime:Memory]"));
    expect(shell, contains("debugPrint('[FK:W:ResourceRuntime:Lifecycle]"));
    expect(shell, contains("debugPrint('[FK:W:ResourceRuntime:Register]"));
  });
}
