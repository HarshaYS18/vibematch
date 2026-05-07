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
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Inbox',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF251538),
                letterSpacing: -0.6,
              ),
            ),
          ),
          _HeaderButton(icon: Icons.search_rounded, onTap: onSearchTap),
          const SizedBox(width: 8),
          _HeaderBadgeButton(icon: Icons.assignment_rounded, count: reportTaskCount, onTap: onReportTasksTap),
          const SizedBox(width: 8),
          _HeaderBadgeButton(icon: Icons.lock_rounded, count: lockedCount, onTap: onLockTap),
          const SizedBox(width: 8),
          _HeaderButton(icon: Icons.settings_rounded, onTap: onSettingsTap),
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
            right: -2,
            top: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE84C72),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
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
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFECE2D8)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF251538).withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF4A2A63), size: 19),
      ),
    );
  }
}
