import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/app/app_routes.dart';
import 'package:vibematch_app/app/runtime/app_shell_navigation_controller.dart';

void main() {
  test('main tab navigation preserves stable branch identity', () {
    final controller = AppShellNavigationController();

    expect(controller.state.selectedTab, VmMainTab.home);
    expect(controller.select(VmMainTab.vibes), isTrue);
    expect(controller.state.previousTab, VmMainTab.home);
    expect(controller.state.selectedTab, VmMainTab.vibes);
    expect(controller.select(VmMainTab.vibes), isFalse);

    controller.select(VmMainTab.home);
    expect(controller.state.selectedTab, VmMainTab.home);

    controller.dispose();
  });
}
