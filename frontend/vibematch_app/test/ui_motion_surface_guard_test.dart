import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all modal sheets use canonical FunKey motion', () {
    final lib = Directory('lib');
    final offenders = <String>[];

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      var searchFrom = 0;

      while (true) {
        final index = source.indexOf('showModalBottomSheet', searchFrom);
        if (index < 0) break;

        final windowEnd = (index + 900).clamp(0, source.length);
        final window = source.substring(index, windowEnd);
        if (!window.contains('sheetAnimationStyle:')) {
          offenders.add(entity.path);
          break;
        }
        searchFrom = index + 'showModalBottomSheet'.length;
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Every modal bottom sheet must use VmMotion.sheetAnimationStyle. '
          'Missing: ${offenders.join(', ')}',
    );
  });

  test('presentation code does not expose raw exception strings', () {
    final lib = Directory('lib/features');
    final offenders = <String>[];

    const forbidden = <String>[
      "error.toString().replaceFirst('Exception: ', '')",
      'error.toString().replaceFirst("Exception: ", "")',
      '_toast(error.toString())',
      '_showToast(error.toString())',
      'errorMessage: error.toString()',
      'Text(error.toString())',
      'Text(snapshot.error.toString())',
    ];

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      final isUserFacing =
          path.contains('/presentation/') ||
          path.contains('/controllers/') ||
          path.contains('/application/');
      if (!isUserFacing) continue;

      final source = entity.readAsStringSync();
      if (forbidden.any(source.contains)) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'User-facing failures must pass through VmFailurePresentation. '
          'Raw exception presentation remains in: ${offenders.join(', ')}',
    );
  });

  test('custom page route builders stay centralized', () {
    final lib = Directory('lib');
    final offenders = <String>[];

    const allowed = <String>{
      'lib/core/ui/vm_motion.dart',
      'lib/features/rooms/presentation/routes/live_room_routes.dart',
    };

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (allowed.contains(path)) continue;
      final source = entity.readAsStringSync();
      if (source.contains('PageRouteBuilder<') ||
          source.contains('PageRouteBuilder(')) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Feature-specific PageRouteBuilder implementations bypass canonical '
          'FunKey motion: ${offenders.join(', ')}',
    );
  });
}
