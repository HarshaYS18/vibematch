import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/app/app_routes.dart';
import 'package:vibematch_app/app/runtime/app_shell_navigation_controller.dart';

void main() {
  test('main tab navigation preserves stable branch identity', () {
    final container = ProviderContainer();
    final subscription = container.listen<AppShellNavigationState>(
      appShellNavigationProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    addTearDown(container.dispose);

    final controller =
        container.read(appShellNavigationProvider.notifier);

    expect(
      container.read(appShellNavigationProvider).selectedTab,
      VmMainTab.home,
    );
    expect(controller.select(VmMainTab.vibes), isTrue);
    expect(
      container.read(appShellNavigationProvider).previousTab,
      VmMainTab.home,
    );
    expect(
      container.read(appShellNavigationProvider).selectedTab,
      VmMainTab.vibes,
    );
    expect(controller.select(VmMainTab.vibes), isFalse);

    controller.select(VmMainTab.home);
    expect(
      container.read(appShellNavigationProvider).selectedTab,
      VmMainTab.home,
    );
  });
}
