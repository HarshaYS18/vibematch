import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/app/runtime/media_resource_coordinator.dart';
import 'package:vibematch_app/foundation/runtime/media_resource_lifecycle.dart';

/// Chunk 34-M6 contract coverage for feature-safe resource registration.
void main() {
  test('coordinator implements the foundation registry port', () {
    final coordinator = MediaResourceCoordinator();
    final MediaResourceRegistry registry = coordinator;

    expect(registry.isForeground, isTrue);
  });

  test('foundation registry provider is nullable unless AppShell overrides it', () {
    final root = ProviderContainer();
    addTearDown(root.dispose);
    expect(root.read(mediaResourceRegistryProvider), isNull);

    final coordinator = MediaResourceCoordinator();
    addTearDown(coordinator.dispose);
    final scoped = ProviderContainer(
      overrides: [
        mediaResourceRegistryProvider.overrideWithValue(coordinator),
      ],
    );
    addTearDown(scoped.dispose);

    expect(scoped.read(mediaResourceRegistryProvider), same(coordinator));
  });

  test('feature-owned resource roots do not import concrete app coordinator', () {
    const roots = <String>[
      'lib/features',
      'lib/game_platform',
      'lib/watch_party',
      'lib/room_media',
    ];

    final offenders = <String>[];
    for (final root in roots) {
      final directory = Directory(root);
      if (!directory.existsSync()) continue;
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        if (source.contains('media_resource_coordinator.dart')) {
          offenders.add(entity.path);
        }
      }
    }

    expect(offenders, isEmpty);
  });
}
