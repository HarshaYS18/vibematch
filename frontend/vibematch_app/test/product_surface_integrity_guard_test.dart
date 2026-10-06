import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical named routes do not render development skeletons', () {
    final source = File('lib/app/app_route_factory.dart').readAsStringSync();

    expect(
      source.contains('VmSkeletonPage'),
      isFalse,
      reason:
          'User-reachable named routes must resolve to real product surfaces '
          'or an honest unsupported-link guard, never VmSkeletonPage.',
    );
  });

  test('app bootstrap respects platform accessibility preferences', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source.contains('textScaler.clamp'), isFalse);
    expect(
      source.contains('MaterialTapTargetSize.shrinkWrap'),
      isFalse,
      reason:
          'Global tap targets must not be reduced below accessible platform '
          'defaults.',
    );
    expect(source.contains('const Size(44, 44)'), isTrue);
  });

  test('production profile does not expose engineering game test UI', () {
    final source = File(
      'lib/features/profile/presentation/widgets/me_page_content.dart',
    ).readAsStringSync();

    expect(source.contains('GameTestPage'), isFalse);
    expect(source.contains('_openGameTest'), isFalse);
  });
}
