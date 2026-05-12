import 'package:flutter/material.dart';

class InboxHeader extends StatelessWidget {
  const InboxHeader({
    super.key,
    required this.lockedCount,
    required this.reportTaskCount,
    required this.onLockTap,
    required this.onReportTasksTap,
    required this.onSettingsTap,
    required this.onSearchTap,
  });

  final int lockedCount;
  final int reportTaskCount;
  final VoidCallback onLockTap;
  final VoidCallback onReportTasksTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF008069),
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 10),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Chats',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.35,
              ),
            ),
          ),
          _HeaderButton(icon: Icons.search_rounded, onTap: onSearchTap),
          const SizedBox(width: 4),
          _HeaderBadgeButton(icon: Icons.assignment_rounded, count: reportTaskCount, onTap: onReportTasksTap),
          const SizedBox(width: 4),
          _HeaderBadgeButton(icon: Icons.lock_rounded, count: lockedCount, onTap: onLockTap),
          const SizedBox(width: 4),
          _HeaderButton(icon: Icons.more_vert_rounded, onTap: onSettingsTap),
        ],
      ),
    );
  }
}

class _HeaderBadgeButton extends StatelessWidget {
  const _HeaderBadgeButton({required this.icon, required this.count, required this.onTap});

  final IconData icon;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _HeaderButton(icon: icon, onTap: onTap),
        if (count > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF008069), width: 1.4),
              ),
              child: Center(
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
