import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chunk 34-M2 source contract.
///
/// AppShell mirrors lifecycle pressure into the session-scoped coordinator
/// while the proven Chunk 13 direct cleanup paths remain frozen in place.
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

  test('M2 preserves direct cleanup until resources migrate individually', () {
    final shell = File('lib/app/app_shell.dart').readAsStringSync();

    expect(shell, contains('_vibePlaybackGate.handleMemoryPressure();'));
    expect(
      shell,
      contains('PaintingBinding.instance.imageCache.clearLiveImages();'),
    );
    expect(shell, contains('ref.read(gameBundleCacheProvider).clear();'));
    expect(shell, contains('unawaited(_reconcileCanonicalShellState());'));
  });

  test('resource lifecycle forwarding is failure-isolated', () {
    final shell = File('lib/app/app_shell.dart').readAsStringSync();

    expect(shell, contains("debugPrint('[FK:W:ResourceRuntime:Memory]"));
    expect(shell, contains("debugPrint('[FK:W:ResourceRuntime:Lifecycle]"));
  });
}
