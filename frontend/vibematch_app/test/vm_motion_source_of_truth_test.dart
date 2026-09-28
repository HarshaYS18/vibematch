import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/core/ui/vm_motion.dart';

void main() {
  test('FunKey route motion stays fast and chat-app style', () {
    expect(VmMotion.pageDuration.inMilliseconds, lessThanOrEqualTo(300));
    expect(VmMotion.pageReverseDuration.inMilliseconds, lessThanOrEqualTo(260));
    expect(VmMotion.tabDuration.inMilliseconds, lessThanOrEqualTo(240));
    expect(VmMotion.pageReverseDuration, lessThan(VmMotion.pageDuration));
  });

  test('all Material routes inherit the canonical transition builder', () {
    final main = File('lib/main.dart').readAsStringSync();
    final routes = File('lib/app/app_route_factory.dart').readAsStringSync();
    final liveRoom = File(
      'lib/features/rooms/presentation/routes/live_room_routes.dart',
    ).readAsStringSync();
    final motion = File('lib/core/ui/vm_motion.dart').readAsStringSync();

    expect(main, contains('FunKeyPageTransitionsBuilder'));
    expect(main, contains('pageTransitionsTheme'));
    expect(routes, contains('VmMotion.pageRoute'));
    expect(liveRoom, contains('VmMotion.buildPageTransition'));
    expect(motion, contains('disableAnimations'));
    expect(motion, contains('secondaryAnimation'));
  });

  test('canonical async presentation primitives remain available', () {
    final states = File(
      'lib/core/presentation/vm_async_state.dart',
    ).readAsStringSync();
    final failure = File('lib/core/network/vm_failure.dart').readAsStringSync();

    expect(states, contains('class VmLoadingState'));
    expect(states, contains('class VmFailureState'));
    expect(states, contains('class VmInlineFailure'));
    expect(states, contains('class VmEmptyState'));
    expect(failure, contains('class VmFailurePresentation'));
    expect(failure, contains('VmFailureKind.offline'));
    expect(failure, contains('status == 401'));
    expect(failure, contains('status == 429'));
  });
}
