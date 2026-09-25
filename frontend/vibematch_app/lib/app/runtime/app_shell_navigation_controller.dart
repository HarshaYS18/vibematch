import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_routes.dart';

class AppShellNavigationState {
  const AppShellNavigationState({
    required this.selectedTab,
    required this.previousTab,
  });

  const AppShellNavigationState.initial()
      : selectedTab = VmMainTab.home,
        previousTab = VmMainTab.home;

  final VmMainTab selectedTab;
  final VmMainTab previousTab;

  AppShellNavigationState select(VmMainTab tab) {
    if (tab == selectedTab) return this;
    return AppShellNavigationState(
      selectedTab: tab,
      previousTab: selectedTab,
    );
  }
}

class AppShellNavigationController
    extends AutoDisposeNotifier<AppShellNavigationState> {
  int _backPressCount = 0;
  Timer? _backPressResetTimer;

  @override
  AppShellNavigationState build() {
    ref.onDispose(() => _backPressResetTimer?.cancel());
    return const AppShellNavigationState.initial();
  }

  bool select(VmMainTab tab) {
    final next = state.select(tab);
    if (identical(next, state)) return false;
    state = next;
    return true;
  }

  int registerBackPress() {
    _backPressCount += 1;
    _backPressResetTimer?.cancel();
    _backPressResetTimer = Timer(
      const Duration(seconds: 2),
      () => _backPressCount = 0,
    );
    return (3 - _backPressCount).clamp(1, 3);
  }
}

final appShellNavigationProvider =
    NotifierProvider.autoDispose<
      AppShellNavigationController,
      AppShellNavigationState
    >(AppShellNavigationController.new);
