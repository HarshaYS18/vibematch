import 'package:flutter/material.dart';

import '../../auth/models/current_user.dart';
import '../../create/presentation/create_page.dart';
import '../../home/presentation/home_page_modular.dart';
import '../../inbox/presentation/inbox_page_modular.dart';
import '../../profile/presentation/me_page.dart';
import '../../vibes/presentation/vibes_page_modular.dart';

enum _DevUserMode {
  founder,
  normalUser,
}

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.currentUser,
    required this.onLogoutPressed,
    required this.onRefreshPressed,
  });

  final CurrentUser currentUser;
  final Future<void> Function() onLogoutPressed;
  final Future<void> Function() onRefreshPressed;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  _DevUserMode _devUserMode = _DevUserMode.founder;

  CurrentUser get _activeUser {
    switch (_devUserMode) {
      case _DevUserMode.founder:
        return CurrentUser.mockFounderOwner();
      case _DevUserMode.normalUser:
        return CurrentUser.mockNormalUser();
    }
  }

  bool get _isTestingAsFounder => _devUserMode == _DevUserMode.founder;

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _switchDevUser(_DevUserMode mode) {
    setState(() {
      _devUserMode = mode;
      _selectedIndex = 4;
    });

    final userLabel =
        mode == _DevUserMode.founder ? 'Founder Owner' : 'Normal User';

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
          content: Text(
            'Testing as $userLabel',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
  }

  List<Widget> get _pages {
    final activeUser = _activeUser;

    return [
      HomePage(
        user: activeUser,
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

  @override
  Widget build(BuildContext context) {
    final activeUser = _activeUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: Column(
        children: [
          _DevUserSwitcher(
            activeUser: activeUser,
            selectedMode: _devUserMode,
            onFounderTap: () => _switchDevUser(_DevUserMode.founder),
            onUserTap: () => _switchDevUser(_DevUserMode.normalUser),
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xFFECE2D8),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF251538).withValues(alpha: 0.08),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              _BottomNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: _selectedIndex == 0,
                onTap: () => _selectTab(0),
              ),
              _BottomNavItem(
                icon: Icons.auto_awesome_rounded,
                label: 'Vibes',
                selected: _selectedIndex == 1,
                onTap: () => _selectTab(1),
              ),
              _CreateCenterButton(
                selected: _selectedIndex == 2,
                onTap: () => _selectTab(2),
              ),
              _BottomNavItem(
                icon: Icons.mail_rounded,
                label: 'Inbox',
                selected: _selectedIndex == 3,
                onTap: () => _selectTab(3),
              ),
              _BottomNavItem(
                icon: _isTestingAsFounder
                    ? Icons.admin_panel_settings_rounded
                    : Icons.person_rounded,
                label: 'Me',
                selected: _selectedIndex == 4,
                onTap: () => _selectTab(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DevUserSwitcher extends StatelessWidget {
  const _DevUserSwitcher({
    required this.activeUser,
    required this.selectedMode,
    required this.onFounderTap,
    required this.onUserTap,
  });

  final CurrentUser activeUser;
  final _DevUserMode selectedMode;
  final VoidCallback onFounderTap;
  final VoidCallback onUserTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      padding: EdgeInsets.fromLTRB(12, topPadding + 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFECE2D8)),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF251538).withValues(alpha: 0.055),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: selectedMode == _DevUserMode.founder
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
              selectedMode == _DevUserMode.founder
                  ? Icons.admin_panel_settings_rounded
                  : Icons.person_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${activeUser.displayName ?? activeUser.username ?? 'Vibe User'} · ${activeUser.primaryRole} · ID ${activeUser.visibleId}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF251538),
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _DevModeButton(
            text: 'Founder',
            selected: selectedMode == _DevUserMode.founder,
            onTap: onFounderTap,
          ),
          const SizedBox(width: 6),
          _DevModeButton(
            text: 'User',
            selected: selectedMode == _DevUserMode.normalUser,
            onTap: onUserTap,
          ),
        ],
      ),
    );
  }
}

class _DevModeButton extends StatelessWidget {
  const _DevModeButton({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF251538) : const Color(0xFFFAF7F1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF251538) : const Color(0xFFECE2D8),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF4A2A63),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF12C7B7).withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected
                    ? const Color(0xFF251538)
                    : const Color(0xFF8C8198),
                size: 22,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF251538)
                      : const Color(0xFF8C8198),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateCenterButton extends StatelessWidget {
  const _CreateCenterButton({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF12C7B7),
                    Color(0xFF6D5DF6),
                    Color(0xFFE84C72),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6D5DF6).withValues(
                      alpha: selected ? 0.30 : 0.20,
                    ),
                    blurRadius: selected ? 22 : 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 31,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
