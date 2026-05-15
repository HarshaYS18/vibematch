import 'dart:async';

import 'package:flutter/material.dart';

import '../core/icons/vm_icons.dart';
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
  final PresenceApiService _presenceApi = const PresenceApiService();
  Timer? _presenceHeartbeatTimer;
  int _homeRefreshNonce = 0;

  CurrentUser get _activeUser => _syncedUser;

  bool get _isTestingAsFounder => _activeUser.canSeeOwnerControls;

  @override
  void initState() {
    super.initState();
    _syncedUser = widget.currentUser;
    _syncVibesPlaybackWithActiveTab();
    LiveRoomMediaSignalingService.instance.setActiveLoggedInUser(_syncedUser);
    _userSyncSubscription = AuthUserRealtimeService.instance.users.listen(_onUserSynced);
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
    VibeMediaPlaybackGate.feedPlaybackPaused.value = true;
    _userSyncSubscription?.cancel();
    _presenceHeartbeatTimer?.cancel();
    unawaited(WalletRealtimeSyncService.instance.stop());
    super.dispose();
  }

  void _syncVibesPlaybackWithActiveTab() {
    final isVibesTabActive = _selectedTab == VmMainTab.vibes;
    VibeMediaPlaybackGate.feedPlaybackPaused.value = !isVibesTabActive;
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
    } catch (_) {
      // Heartbeat should never block app navigation. Auth/API errors are handled elsewhere.
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: Stack(
        children: [
          IndexedStack(index: _selectedTab.tabIndex, children: _pages),
          const _LiveRoomMiniBubbleLayer(),
        ],
      ),
      bottomNavigationBar: _VibeBottomNav(selectedTab: _selectedTab, isTestingAsFounder: _isTestingAsFounder, onTabSelected: _selectTab),
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
    final maxX = size.width - 86;
    final maxY = size.height - bottomSafeArea - 96;

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

  static const Color deepPlum = Color(0xFF251538);
  static const Color softBorder = Color(0xFFECE2D8);
  static const Color aqua = Color(0xFF12C7B7);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: softBorder),
          boxShadow: [BoxShadow(color: deepPlum.withValues(alpha: 0.08), blurRadius: 22, offset: const Offset(0, 8))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: VMIcons.home, label: VmMainTab.home.label, active: selectedTab == VmMainTab.home, onTap: () => onTabSelected(VmMainTab.home)),
            _NavItem(icon: VMIcons.vibes, label: VmMainTab.vibes.label, active: selectedTab == VmMainTab.vibes, onTap: () => onTabSelected(VmMainTab.vibes)),
            _NavItem(icon: VMIcons.inbox, label: VmMainTab.inbox.label, active: selectedTab == VmMainTab.inbox, onTap: () => onTabSelected(VmMainTab.inbox)),
            _NavItem(icon: isTestingAsFounder ? VMIcons.admin : VMIcons.profile, label: VmMainTab.me.label, active: selectedTab == VmMainTab.me, onTap: () => onTabSelected(VmMainTab.me)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  static const Color deepPlum = Color(0xFF251538);
  static const Color muted = Color(0xFF8C8198);
  static const Color aqua = Color(0xFF12C7B7);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: active ? aqua.withValues(alpha: 0.11) : Colors.transparent, borderRadius: BorderRadius.circular(18)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: active ? deepPlum : muted),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? deepPlum : muted)),
          ],
        ),
      ),
    );
  }
}
