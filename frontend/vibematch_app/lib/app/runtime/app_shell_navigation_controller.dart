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
    extends StateNotifier<AppShellNavigationState> {
  AppShellNavigationController()
      : super(const AppShellNavigationState.initial());

  int _backPressCount = 0;
  Timer? _backPressResetTimer;

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

  @override
  void dispose() {
    _backPressResetTimer?.cancel();
    super.dispose();
  }
}

final appShellNavigationProvider = StateNotifierProvider.autoDispose<
    AppShellNavigationController,
    AppShellNavigationState>(
  (ref) => AppShellNavigationController(),
);
