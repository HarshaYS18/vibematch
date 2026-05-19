import 'dart:async';

import 'package:flutter/material.dart';

import '../core/icons/vm_icons.dart';
import '../core/session/vm_session_cleanup_service.dart';
import '../features/auth/data/auth_api_service.dart';
import '../features/auth/models/current_user.dart';
import '../features/home/presentation/home_page_modular.dart';
import '../features/inbox/controllers/inbox_controller.dart';
import '../features/inbox/models/inbox_models.dart';
import '../features/inbox/presentation/inbox_page_modular.dart';
import '../features/inbox/presentation/widgets/inbox_foreground_notification_banner.dart';
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
  final InboxController _inboxController = InboxController();
  bool _inboxRealtimeReady = false;
  String? _lastGlobalInboxMessageKey;
  InboxConversation? _globalForegroundConversation;
  InboxMessage? _globalForegroundMessage;
  Timer? _globalForegroundDismissTimer;
  String? _pendingInboxOpenConversationId;
  int _pendingInboxOpenRequestNonce = 0;
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
    _inboxController.addListener(_handleGlobalInboxChanged);
    unawaited(_startGlobalInboxRealtime());
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
    _globalForegroundDismissTimer?.cancel();
    _inboxController.removeListener(_handleGlobalInboxChanged);
    _inboxController.dispose();
    unawaited(WalletRealtimeSyncService.instance.stop());
    super.dispose();
  }

  Future<void> _startGlobalInboxRealtime() async {
    await _inboxController.loadFromBackend();
    _lastGlobalInboxMessageKey = _latestIncomingInboxKey();
    _inboxRealtimeReady = true;
  }

  String? _latestIncomingInboxKey() {
    for (final conversation in _inboxController.conversations) {
      if (conversation.messages.isEmpty) continue;
      final message = conversation.messages.last;
      if (message.isMine) continue;
      return _globalInboxMessageKey(conversation, message);
    }
    return null;
  }

  String _globalInboxMessageKey(
    InboxConversation conversation,
    InboxMessage message,
  ) {
    return '${conversation.id}:${message.id ?? message.text}:${message.time}';
  }

  void _handleGlobalInboxChanged() {
    if (!_inboxRealtimeReady || !mounted) return;

    for (final conversation in _inboxController.conversations) {
      if (conversation.messages.isEmpty) continue;
      if (conversation.isMuted || conversation.isLockedByBackend) continue;

      final message = conversation.messages.last;
      if (message.isMine) continue;

      final key = _globalInboxMessageKey(conversation, message);
      if (key == _lastGlobalInboxMessageKey) return;

      _lastGlobalInboxMessageKey = key;
      _globalForegroundConversation = conversation;
      _globalForegroundMessage = message;

      _globalForegroundDismissTimer?.cancel();
      _globalForegroundDismissTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        setState(() {
          _globalForegroundConversation = null;
          _globalForegroundMessage = null;
        });
      });

      setState(() {});
      return;
    }
  }

  void _dismissGlobalForegroundNotification() {
    _globalForegroundDismissTimer?.cancel();
    setState(() {
      _globalForegroundConversation = null;
      _globalForegroundMessage = null;
    });
  }

  void _openGlobalForegroundNotification() {
    final conversation = _globalForegroundConversation;
    if (conversation == null) {
      _selectTab(VmMainTab.inbox);
      return;
    }

    _globalForegroundDismissTimer?.cancel();
    setState(() {
      _pendingInboxOpenConversationId = conversation.id;
      _pendingInboxOpenRequestNonce += 1;
      _globalForegroundConversation = null;
      _globalForegroundMessage = null;
      _selectedTab = VmMainTab.inbox;
    });
    _syncVibesPlaybackWithActiveTab();
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
      InboxPage(
        controller: _inboxController,
        openConversationId: _pendingInboxOpenConversationId,
        openConversationRequestNonce: _pendingInboxOpenRequestNonce,
      ),
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
            if (_globalForegroundConversation != null && _globalForegroundMessage != null)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: InboxForegroundNotificationBanner(
                  conversation: _globalForegroundConversation!,
                  message: _globalForegroundMessage!,
                  onTap: _openGlobalForegroundNotification,
                  onClose: _dismissGlobalForegroundNotification,
                ),
              ),
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

  static const Color deepPlum = Color(0xFF251538);
  static const Color softBorder = Color(0xFFECE2D8);
  static const Color aqua = Color(0xFF12C7B7);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 3, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: softBorder),
          boxShadow: [BoxShadow(color: deepPlum.withValues(alpha: 0.07), blurRadius: 18, offset: const Offset(0, 7))],
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
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: active ? aqua.withValues(alpha: 0.1) : Colors.transparent, borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: active ? deepPlum : muted),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                height: 1.0,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? deepPlum : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}