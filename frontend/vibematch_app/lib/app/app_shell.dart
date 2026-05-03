import 'package:flutter/material.dart';

import '../features/auth/models/current_user.dart';
import '../features/create/presentation/create_page.dart';
import '../features/home/presentation/home_page_modular.dart';
import '../features/inbox/presentation/inbox_page.dart';
import '../features/profile/presentation/me_page.dart';
import '../features/rooms/presentation/widgets/live_room_minimized_bubble.dart';
import '../features/rooms/presentation/widgets/live_room_minimized_overlay_service.dart';
import '../features/vibes/presentation/vibes_page.dart';
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

  List<Widget> get _pages {
    final activeUser = widget.currentUser;

    return [
      HomePage(
        user: activeUser,
        currentUser: activeUser,
      ),
      const VibesPage(),
      const CreatePage(),
      const InboxPage(),
      MePage(
        user: activeUser,
        onLogoutPressed: widget.onLogoutPressed,
        onRefreshPressed: widget.onRefreshPressed,
      ),
    ];
  }

  void _selectTab(VmMainTab tab) {
    if (_selectedTab == tab) return;

    setState(() {
      _selectedTab = tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeUser = widget.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: Stack(
        children: [
          Column(
            children: [
              _ActiveAccountStrip(
                activeUser: activeUser,
                onRefreshTap: () async {
                  await widget.onRefreshPressed();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(
                      const SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Color(0xFF251538),
                        content: Text(
                          'Account refreshed',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    );
                },
                onLogoutTap: widget.onLogoutPressed,
              ),
              Expanded(
                child: IndexedStack(
                  index: _selectedTab.tabIndex,
                  children: _pages,
                ),
              ),
            ],
          ),
          const _LiveRoomMiniBubbleLayer(),
        ],
      ),
      bottomNavigationBar: _VibeBottomNav(
        selectedTab: _selectedTab,
        isFounderOwner: activeUser.isFounderOwner,
        onTabSelected: _selectTab,
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

class _ActiveAccountStrip extends StatelessWidget {
  const _ActiveAccountStrip({
    required this.activeUser,
    required this.onRefreshTap,
    required this.onLogoutTap,
  });

  final CurrentUser activeUser;
  final VoidCallback onRefreshTap;
  final Future<void> Function() onLogoutTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final isFounder = activeUser.isFounderOwner;

    return Container(
      padding: EdgeInsets.fromLTRB(12, topPadding + 6, 8, 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFECE2D8)),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF251538).withValues(alpha: 0.045),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: LinearGradient(
                colors: isFounder
                    ? const [
                        Color(0xFFFFC857),
                        Color(0xFFE84C72),
                        Color(0xFF8C5CF6),
                      ]
                    : const [
                        Color(0xFF12C7B7),
                        Color(0xFF6D5DF6),
                      ],
              ),
            ),
            child: Icon(
              isFounder ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '${activeUser.displayName ?? activeUser.username ?? 'Vibe User'} · ${activeUser.roleDisplayLabel} · ID ${activeUser.visibleId}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF251538),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh account',
            onPressed: onRefreshTap,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF4A2A63), size: 20),
          ),
          IconButton(
            tooltip: 'Switch login',
            onPressed: () => onLogoutTap(),
            icon: const Icon(Icons.switch_account_rounded, color: Color(0xFFE84C72), size: 20),
          ),
        ],
      ),
    );
  }
}

class _VibeBottomNav extends StatelessWidget {
  const _VibeBottomNav({
    required this.selectedTab,
    required this.isFounderOwner,
    required this.onTabSelected,
  });

  final VmMainTab selectedTab;
  final bool isFounderOwner;
  final ValueChanged<VmMainTab> onTabSelected;

  static const Color deepPlum = Color(0xFF251538);
  static const Color softBorder = Color(0xFFECE2D8);
  static const Color aqua = Color(0xFF12C7B7);
  static const Color violet = Color(0xFF6D5DF6);
  static const Color coral = Color(0xFFE84C72);

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
          boxShadow: [
            BoxShadow(
              color: deepPlum.withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: VmMainTab.home.label,
              active: selectedTab == VmMainTab.home,
              onTap: () => onTabSelected(VmMainTab.home),
            ),
            _NavItem(
              icon: Icons.auto_awesome_rounded,
              label: VmMainTab.vibes.label,
              active: selectedTab == VmMainTab.vibes,
              onTap: () => onTabSelected(VmMainTab.vibes),
            ),
            GestureDetector(
              onTap: () => onTabSelected(VmMainTab.create),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [aqua, violet, coral],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: violet.withValues(alpha: selectedTab == VmMainTab.create ? 0.44 : 0.34),
                      blurRadius: selectedTab == VmMainTab.create ? 23 : 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            _NavItem(
              icon: Icons.mail_rounded,
              label: VmMainTab.inbox.label,
              active: selectedTab == VmMainTab.inbox,
              onTap: () => onTabSelected(VmMainTab.inbox),
            ),
            _NavItem(
              icon: isFounderOwner
                  ? Icons.admin_panel_settings_rounded
                  : Icons.person_rounded,
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
  });

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
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: active ? aqua.withValues(alpha: 0.11) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: active ? deepPlum : muted,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
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
