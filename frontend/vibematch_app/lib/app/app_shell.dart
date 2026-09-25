import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/icons/vm_icons.dart';
import '../core/permissions/vm_android_permission_service.dart';
import '../core/ui/vm_motion.dart';
import '../core/ui/vm_toast.dart';
import '../features/auth/models/current_user.dart';
import '../features/home/presentation/home_page_modular.dart';
import '../game_platform/data/game_manifest_repository.dart';
import '../features/inbox/controllers/inbox_controller.dart';
import '../features/inbox/presentation/inbox_page.dart';
import '../features/inbox/presentation/widgets/inbox_foreground_notification_banner.dart';
import '../features/profile/presentation/me_page.dart';
import '../features/rooms/data/live_room_media_signaling_service.dart';
import '../features/rooms/presentation/widgets/live_room_minimized_bubble.dart';
import '../features/rooms/presentation/widgets/live_room_minimized_overlay_service.dart';
import '../features/vibes/presentation/vibes_page_modular.dart';
import '../features/vibes/presentation/widgets/vibe_media_playback_gate.dart';
import '../identity/data/identity_repository.dart';
import '../session/data/session_repository.dart';
import 'runtime/app_identity_runtime.dart';
import 'runtime/app_inbox_runtime.dart';
import '../realtime/app_realtime_hub.dart';
import 'runtime/app_shell_navigation_controller.dart';
import 'runtime/media_resource_coordinator.dart';
import 'runtime/app_wallet_runtime.dart';
import 'app_routes.dart';
import 'app_source_registry_repository.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    required this.currentUser,
    required this.onLogoutPressed,
  });

  final CurrentUser currentUser;
  final Future<void> Function() onLogoutPressed;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  final AppSourceRegistryRepository _sourceRegistryRepository =
      AppSourceRegistryRepository();
  final VmAndroidPermissionService _permissionService =
      const VmAndroidPermissionService();

  bool _sessionLogoutInFlight = false;
  bool _canonicalRefreshInFlight = false;
  late final VibeMediaPlaybackGate _vibePlaybackGate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vibePlaybackGate = VibeMediaPlaybackGate(initiallyPaused: true);

    ref.read(identityRepositoryProvider.notifier).accept(widget.currentUser);
    LiveRoomMediaSignalingService.instance.setActiveLoggedInUser(
      widget.currentUser,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_startShellRuntimes());
      unawaited(_validateAppSourceRegistry());
      unawaited(_permissionService.requestAppLaunchPermissions());
    });
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser != widget.currentUser) {
      ref.read(identityRepositoryProvider.notifier).accept(widget.currentUser);
      LiveRoomMediaSignalingService.instance.setActiveLoggedInUser(
        widget.currentUser,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vibePlaybackGate.setTabPaused(true);
    _vibePlaybackGate.clearPauseLocks();
    _vibePlaybackGate.dispose();
    _sourceRegistryRepository.close();
    super.dispose();
  }

  @override
  void didHaveMemoryPressure() {
    // Chunk 34 mirror phase: notify the session-scoped coordinator while
    // preserving every existing direct cleanup path until each resource owner
    // is migrated and independently guarded.
    unawaited(_notifyResourceMemoryPressure());
    _vibePlaybackGate.handleMemoryPressure();
    PaintingBinding.instance.imageCache.clearLiveImages();
    ref.read(gameBundleCacheProvider).clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The coordinator receives lifecycle pressure only. It does not become
    // authority for session, navigation, playback, room, or game state.
    unawaited(
      _notifyResourceForegroundState(state == AppLifecycleState.resumed),
    );
    if (state == AppLifecycleState.resumed) {
      unawaited(_reconcileCanonicalShellState());
    }
  }

  Future<void> _notifyResourceMemoryPressure() async {
    try {
      await ref.read(mediaResourceCoordinatorProvider).handleMemoryPressure();
    } catch (error) {
      debugPrint('[FK:W:ResourceRuntime:Memory] $error');
    }
  }

  Future<void> _notifyResourceForegroundState(bool isForeground) async {
    try {
      await ref
          .read(mediaResourceCoordinatorProvider)
          .setForeground(isForeground);
    } catch (error) {
      debugPrint('[FK:W:ResourceRuntime:Lifecycle] $error');
    }
  }

  Future<void> _startShellRuntimes() async {
    ref
        .read(appIdentityRuntimeProvider)
        .start(initialUser: widget.currentUser);

    final realtime = ref.read(appRealtimeHubProvider);
    await realtime.start();

    await Future.wait<void>([
      ref.read(appInboxRuntimeProvider.notifier).start(),
      ref.read(appWalletRuntimeProvider).start(),
    ]);
  }

  Future<void> _handleAuthoritativeSessionInvalidation() async {
    if (_sessionLogoutInFlight) return;
    _sessionLogoutInFlight = true;
    await widget.onLogoutPressed();
  }

  Future<void> _validateAppSourceRegistry() async {
    try {
      await _sourceRegistryRepository.fetchAndValidate();
    } catch (error) {
      debugPrint('[FK:W:SourceRegistry] $error');
    }
  }

  Future<void> _reconcileCanonicalShellState() async {
    if (_canonicalRefreshInFlight || _sessionLogoutInFlight) return;
    _canonicalRefreshInFlight = true;
    final sessions = ref.read(sessionRepositoryProvider.notifier);
    try {
      final user = await sessions.refresh();
      ref.read(identityRepositoryProvider.notifier).accept(user);
      LiveRoomMediaSignalingService.instance.setActiveLoggedInUser(user);

      await ref.read(appRealtimeHubProvider).start();
      await Future.wait<void>([
        ref.read(appInboxRuntimeProvider.notifier).ensureRealtimeConnected(),
        ref.read(appWalletRuntimeProvider).start(),
      ]);
    } catch (error) {
      if (sessions.isAuthoritativeFailure(error)) {
        await _handleAuthoritativeSessionInvalidation();
      } else {
        debugPrint('[FK:W:ShellReconcile] $error');
      }
    } finally {
      _canonicalRefreshInFlight = false;
    }
  }

  void _selectTab(VmMainTab tab) {
    final navigation = ref.read(appShellNavigationProvider.notifier);
    if (!navigation.select(tab)) return;
    _syncVibesPlaybackWithActiveTab(tab);
  }

  void _syncVibesPlaybackWithActiveTab(VmMainTab selectedTab) {
    final isVibesTabActive = selectedTab == VmMainTab.vibes;
    _vibePlaybackGate.setTabPaused(!isVibesTabActive);
    if (isVibesTabActive) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _vibePlaybackGate.notifyFeedScrolled(),
      );
    }
  }

  void _openGlobalForegroundNotification() {
    ref.read(appInboxRuntimeProvider.notifier).openForegroundNotification();
    _selectTab(VmMainTab.inbox);
  }

  void _handleAppBack(bool didPop, Object? result) {
    if (didPop) return;
    final navigation = ref.read(appShellNavigationProvider.notifier);
    final selected = ref.read(appShellNavigationProvider).selectedTab;
    if (selected != VmMainTab.home) {
      _selectTab(VmMainTab.home);
      return;
    }

    final remaining = navigation.registerBackPress();
    VmToast.show(
      context,
      'Press back $remaining more time${remaining == 1 ? '' : 's'} to exit',
      icon: Icons.touch_app_rounded,
      duration: const Duration(milliseconds: 1300),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watching these providers keeps session-scoped runtimes alive only while
    // the authenticated shell is mounted.
    ref.watch(appIdentityRuntimeProvider);
    ref.watch(appRealtimeHubProvider);
    ref.watch(appWalletRuntimeProvider);
    // Chunk 34: registry lifetime exactly matches the authenticated AppShell.
    // M2 only mirrors lifecycle signals; no feature resource is migrated yet.
    ref.watch(mediaResourceCoordinatorProvider);

    final navigation = ref.watch(appShellNavigationProvider);
    final identity = ref.watch(identityRepositoryProvider);
    final inboxRuntimeState = ref.watch(appInboxRuntimeProvider);
    final inboxRuntime = ref.read(appInboxRuntimeProvider.notifier);
    final inboxState = ref.watch(inboxControllerProvider);
    final inboxController = ref.read(inboxControllerProvider.notifier);
    final activeUser = identity.user ?? widget.currentUser;

    ref.listen<CurrentUser?>(
      identityRepositoryProvider.select((state) => state.user),
      (previous, next) {
        if (next != null && next != previous) {
          LiveRoomMediaSignalingService.instance.setActiveLoggedInUser(next);
        }
      },
    );

    final pages = <Widget>[
      HomePage(
        key: const PageStorageKey<String>('main-home'),
        user: activeUser,
        currentUser: activeUser,
      ),
      VibesPage(
        key: const PageStorageKey<String>('main-vibes'),
        playbackGate: _vibePlaybackGate,
      ),
      InboxPage(
        key: const PageStorageKey<String>('main-inbox'),
        controller: inboxController,
        openConversationId: inboxRuntimeState.pendingOpenConversationId,
        openConversationRequestNonce: inboxRuntimeState.pendingOpenRequestNonce,
        onActiveConversationChanged: inboxRuntime.setActiveConversation,
      ),
      MePage(
        key: const PageStorageKey<String>('main-me'),
        user: activeUser,
        onLogoutPressed: widget.onLogoutPressed,
        onRefreshPressed: _reconcileCanonicalShellState,
      ),
    ];

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: _handleAppBack,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF7F1),
        body: Stack(
          children: [
            _PersistentTabStage(
              selectedTab: navigation.selectedTab,
              previousTab: navigation.previousTab,
              pages: pages,
            ),
            const _LiveRoomMiniBubbleLayer(),
            if (inboxRuntimeState.foregroundConversation != null &&
                inboxRuntimeState.foregroundMessage != null)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: InboxForegroundNotificationBanner(
                  conversation: inboxRuntimeState.foregroundConversation!,
                  message: inboxRuntimeState.foregroundMessage!,
                  onTap: _openGlobalForegroundNotification,
                  onClose: inboxRuntime.dismissForegroundNotification,
                ),
              ),
          ],
        ),
        bottomNavigationBar: _VibeBottomNav(
          selectedTab: navigation.selectedTab,
          showOwnerControls: activeUser.canSeeOwnerControls,
          inboxUnreadCount: inboxState.unreadCount,
          onTabSelected: _selectTab,
        ),
      ),
    );
  }
}

class _PersistentTabStage extends StatelessWidget {
  const _PersistentTabStage({
    required this.selectedTab,
    required this.previousTab,
    required this.pages,
  });

  final VmMainTab selectedTab;
  final VmMainTab previousTab;
  final List<Widget> pages;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final tab in VmMainTab.values)
          _PersistentTabBranch(
            active: selectedTab == tab,
            direction: selectedTab.tabIndex >= previousTab.tabIndex ? 1 : -1,
            child: pages[tab.tabIndex],
          ),
      ],
    );
  }
}

class _PersistentTabBranch extends StatelessWidget {
  const _PersistentTabBranch({
    required this.active,
    required this.direction,
    required this.child,
  });

  final bool active;
  final int direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hiddenOffset = Offset(0.025 * direction, 0);
    return IgnorePointer(
      ignoring: !active,
      child: TickerMode(
        enabled: active,
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: VmMotion.tabDuration,
          curve: active ? VmMotion.enterCurve : VmMotion.exitCurve,
          child: AnimatedSlide(
            offset: active ? Offset.zero : hiddenOffset,
            duration: VmMotion.tabDuration,
            curve: active ? VmMotion.enterCurve : VmMotion.exitCurve,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _LiveRoomMiniBubbleLayer extends StatefulWidget {
  const _LiveRoomMiniBubbleLayer();
  @override
  State<_LiveRoomMiniBubbleLayer> createState() =>
      _LiveRoomMiniBubbleLayerState();
}

class _LiveRoomMiniBubbleLayerState extends State<_LiveRoomMiniBubbleLayer> {
  final LiveRoomMinimizedOverlayService _service =
      LiveRoomMinimizedOverlayService.instance;
  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_service.isShowing) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;
    final maxX = size.width - 78;
    final maxY = size.height - bottomSafeArea - 88;
    return LiveRoomMinimizedBubble(
      offset: _service.offset,
      onRestore: _service.restore,
      onDrag: (details) {
        final nextOffset = Offset(
          (_service.offset.dx + details.delta.dx).clamp(8.0, maxX),
          (_service.offset.dy + details.delta.dy).clamp(40.0, maxY),
        );
        _service.updateOffset(nextOffset);
      },
    );
  }
}

class _VibeBottomNav extends StatelessWidget {
  const _VibeBottomNav({
    required this.selectedTab,
    required this.showOwnerControls,
    required this.inboxUnreadCount,
    required this.onTabSelected,
  });
  final VmMainTab selectedTab;
  final bool showOwnerControls;
  final int inboxUnreadCount;
  final ValueChanged<VmMainTab> onTabSelected;
  static const Color deepPlum = Color(0xFF251538);
  static const Color softBorder = Color(0xFFECE2D8);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 2, 12, 7),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: softBorder),
          boxShadow: [
            BoxShadow(
              color: deepPlum.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: VMIcons.home,
              label: VmMainTab.home.label,
              active: selectedTab == VmMainTab.home,
              onTap: () => onTabSelected(VmMainTab.home),
            ),
            _NavItem(
              icon: VMIcons.vibes,
              label: VmMainTab.vibes.label,
              active: selectedTab == VmMainTab.vibes,
              onTap: () => onTabSelected(VmMainTab.vibes),
            ),
            _NavItem(
              icon: VMIcons.inbox,
              label: VmMainTab.inbox.label,
              active: selectedTab == VmMainTab.inbox,
              badgeCount: inboxUnreadCount,
              onTap: () => onTabSelected(VmMainTab.inbox),
            ),
            _NavItem(
              icon: showOwnerControls ? VMIcons.admin : VMIcons.profile,
              label: VmMainTab.me.label,
              active: selectedTab == VmMainTab.me,
              onTap: () => onTabSelected(VmMainTab.me),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badgeCount = 0,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badgeCount;
  static const Color deepPlum = Color(0xFF251538);
  static const Color muted = Color(0xFF8C8198);
  static const Color aqua = Color(0xFF12C7B7);
  static const Color coral = Color(0xFFE84C72);

  @override
  Widget build(BuildContext context) {
    final showBadge = badgeCount > 0;
    final badgeText = badgeCount > 99 ? '99+' : '$badgeCount';
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: AnimatedContainer(
        duration: VmMotion.actionDuration,
        curve: VmMotion.standardCurve,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? aqua.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: active ? 1.05 : 1.0,
                  duration: VmMotion.actionDuration,
                  curve: VmMotion.standardCurve,
                  child: Icon(
                    icon,
                    size: active ? 18 : 17,
                    color: active ? deepPlum : muted,
                  ),
                ),
                if (showBadge)
                  Positioned(
                    right: -9,
                    top: -7,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 15,
                        minHeight: 15,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: coral,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: coral.withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          height: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 8.4,
                height: 0.98,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? deepPlum : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
