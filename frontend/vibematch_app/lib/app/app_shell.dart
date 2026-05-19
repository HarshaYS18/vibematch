import 'dart:async';

import 'package:flutter/material.dart';

import '../core/icons/vm_icons.dart';
import '../core/session/vm_session_cleanup_service.dart';
import '../features/auth/data/auth_api_service.dart';
import '../features/auth/models/current_user.dart';
import '../features/home/presentation/home_page_modular.dart';
import '../features/inbox/presentation/inbox_page_modular.dart';
import '../features/profile/presentation/me_page.dart';
import '../features/presence/data/presence_api_service.dart';
import '../features/rooms/data/live_room_media_signaling_service.dart';
import '../features/rooms/presentation/widgets/live_room_minimized_bubble.dart';
import '../features/rooms/presentation/widgets/live_room_minimized_overlay_service.dart';
import '../features/vibes/presentation/vibes_page_modular.dart';
import '../features/vibes/presentation/widgets/vibe_media_playback_gate.dart';
import '../features/wallet/data/wallet_realtime_sync_service.dart';
import 'app_routes.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.currentUser,
    required this.onLogoutPressed,
    required this.onRefreshPressed,
  });

  final CurrentUser currentUser;
  final Future<void> Function() onLogoutPressed;
  final Future<void> Function() onRefreshPressed;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  VmMainTab _selectedTab = VmMainTab.home;
  late CurrentUser _syncedUser;
  StreamSubscription<CurrentUser>? _userSyncSubscription;
  StreamSubscription<void>? _signedOutSubscription;
  final PresenceApiService _presenceApi = const PresenceApiService();
  Timer? _presenceHeartbeatTimer;
  int _homeRefreshNonce = 0;
  int _backPressCount = 0;
  Timer? _backPressResetTimer;
  bool _sessionLogoutInFlight = false;

  CurrentUser get _activeUser => _syncedUser;

  bool get _isTestingAsFounder => _activeUser.canSeeOwnerControls;

  @override
  void initState() {
    super.initState();
    _syncedUser = widget.currentUser;
    _syncVibesPlaybackWithActiveTab();
    LiveRoomMediaSignalingService.instance.setActiveLoggedInUser(_syncedUser);
    _userSyncSubscription = AuthUserRealtimeService.instance.users.listen(_onUserSynced);
    _signedOutSubscription = AuthUserRealtimeService.instance.signedOut.listen((_) => _handleSignedOut());
    _startPresenceHeartbeat();
    unawaited(WalletRealtimeSyncService.instance.start());
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser != widget.currentUser) {
      _onUserSynced(widget.currentUser);
    }
  }

  @override
  void dispose() {
    VibeMediaPlaybackGate.setTabPaused(true);
    VibeMediaPlaybackGate.clearPauseLocks();
    _userSyncSubscription?.cancel();
    _signedOutSubscription?.cancel();
    _presenceHeartbeatTimer?.cancel();
    _backPressResetTimer?.cancel();
    unawaited(WalletRealtimeSyncService.instance.stop());
    super.dispose();
  }

  void _syncVibesPlaybackWithActiveTab() {
    final isVibesTabActive = _selectedTab == VmMainTab.vibes;
    VibeMediaPlaybackGate.setTabPaused(!isVibesTabActive);
    if (isVibesTabActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => VibeMediaPlaybackGate.notifyFeedScrolled());
    }
  }

  void _startPresenceHeartbeat() {
    _presenceHeartbeatTimer?.cancel();
    unawaited(_sendPresenceHeartbeat());
    _presenceHeartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_sendPresenceHeartbeat()),
    );
  }

  Future<void> _sendPresenceHeartbeat() async {
    try {
      await _presenceApi.heartbeat();
    } catch (error) {
      final message = error.toString().toLowerCase();
      final sessionInvalid =
          message.contains('session replaced') ||
          message.contains('invalid or expired token') ||
          message.contains('please login again');
      if (!sessionInvalid || _sessionLogoutInFlight) return;
      _sessionLogoutInFlight = true;
      await widget.onLogoutPressed();
    }
  }

  void _handleSignedOut() {
    _presenceHeartbeatTimer?.cancel();
    VmSessionCleanupService.clearUserScopedStateUnawaited(reason: 'app shell signed out');
  }

  void _onUserSynced(CurrentUser user) {
    LiveRoomMediaSignalingService.instance.setActiveLoggedInUser(user);
    if (!mounted) return;
    setState(() => _syncedUser = user);
  }

  Future<void> _refreshAndSyncUser() async {
    await widget.onRefreshPressed();
    final cached = const AuthApiService().cachedUser;
    if (cached != null) _onUserSynced(cached);
  }

  List<Widget> get _pages {
    final activeUser = _activeUser;

    return [
      HomePage(key: ValueKey('home_$_homeRefreshNonce'), user: activeUser, currentUser: activeUser),
      const VibesPage(),
      const InboxPage(),
      MePage(user: activeUser, onLogoutPressed: widget.onLogoutPressed, onRefreshPressed: _refreshAndSyncUser),
    ];
  }

  void _selectTab(VmMainTab tab) {
    if (_selectedTab == tab) return;
    setState(() {
      _selectedTab = tab;
      if (tab == VmMainTab.home) _homeRefreshNonce += 1;
    });
    _syncVibesPlaybackWithActiveTab();
  }

  void _handleAppBack(bool didPop, Object? result) {
    if (didPop) return;

    if (_selectedTab != VmMainTab.home) {
      _selectTab(VmMainTab.home);
      return;
    }

    _backPressCount += 1;
    _backPressResetTimer?.cancel();
    _backPressResetTimer = Timer(const Duration(seconds: 2), () => _backPressCount = 0);

    final remaining = (3 - _backPressCount).clamp(1, 3);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Press back $remaining more time${remaining == 1 ? '' : 's'} to exit'),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: _handleAppBack,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF7F1),
        body: Stack(
          children: [
            IndexedStack(index: _selectedTab.tabIndex, children: _pages),
            const _LiveRoomMiniBubbleLayer(),
          ],
        ),
        bottomNavigationBar: _VibeBottomNav(selectedTab: _selectedTab, isTestingAsFounder: _isTestingAsFounder, onTabSelected: _selectTab),
      ),
    );
  }
}

class _LiveRoomMiniBubbleLayer extends StatefulWidget {
  const _LiveRoomMiniBubbleLayer();

  @override
  State<_LiveRoomMiniBubbleLayer> createState() => _LiveRoomMiniBubbleLayerState();
}

class _LiveRoomMiniBubbleLayerState extends State<_LiveRoomMiniBubbleLayer> {
  final LiveRoomMinimizedOverlayService _service = LiveRoomMinimizedOverlayService.instance;

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
  const _VibeBottomNav({required this.selectedTab, required this.isTestingAsFounder, required this.onTabSelected});

  final VmMainTab selectedTab;
  final bool isTestingAsFounder;
  final ValueChanged<VmMainTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding + 8),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F1),
        border: Border(top: BorderSide(color: Color(0xFFECE2D8))),
      ),
      child: Row(
        children: [
          _BottomNavItem(tab: VmMainTab.home, selectedTab: selectedTab, onTap: onTabSelected),
          _BottomNavItem(tab: VmMainTab.vibes, selectedTab: selectedTab, onTap: onTabSelected),
          const _CreateRoomButton(),
          _BottomNavItem(tab: VmMainTab.inbox, selectedTab: selectedTab, onTap: onTabSelected),
          _BottomNavItem(tab: VmMainTab.me, selectedTab: selectedTab, onTap: onTabSelected),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({required this.tab, required this.selectedTab, required this.onTap});

  final VmMainTab tab;
  final VmMainTab selectedTab;
  final ValueChanged<VmMainTab> onTap;

  IconData get _icon {
    return switch (tab) {
      VmMainTab.home => VMIcons.home,
      VmMainTab.vibes => VMIcons.vibes,
      VmMainTab.inbox => VMIcons.inbox,
      VmMainTab.me => VMIcons.profile,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(tab),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, size: 25, color: isSelected ? const Color(0xFF4A2A63) : const Color(0xFF9A8DA6)),
              const SizedBox(height: 3),
              Text(tab.label, style: TextStyle(color: isSelected ? const Color(0xFF4A2A63) : const Color(0xFF9A8DA6), fontSize: 11, fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateRoomButton extends StatelessWidget {
  const _CreateRoomButton();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: InkWell(
          onTap: () => Navigator.of(context).pushNamed(VmRoutes.create),
          borderRadius: BorderRadius.circular(26),
          child: Container(
            width: 54,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(23),
              gradient: const LinearGradient(colors: [Color(0xFF12C7B7), Color(0xFF6D5DF6)]),
              boxShadow: [BoxShadow(color: const Color(0xFF12C7B7).withValues(alpha: 0.26), blurRadius: 18, offset: const Offset(0, 8))],
            ),
            child: const Icon(VMIcons.create, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
