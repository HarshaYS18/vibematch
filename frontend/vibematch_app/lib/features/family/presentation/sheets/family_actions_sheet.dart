import 'package:flutter/material.dart';

import '../widgets/family_redesign_shared.dart';

class FamilyActionsSheet extends StatelessWidget {
  const FamilyActionsSheet({
    super.key,
    required this.isOwner,
    required this.adminCount,
    required this.adminCapacity,
    required this.onSetAdmins,
    required this.onExit,
    required this.onDisband,
  });

  final bool isOwner;
  final int adminCount;
  final int adminCapacity;
  final VoidCallback onSetAdmins;
  final VoidCallback onExit;
  final VoidCallback onDisband;

  @override
  Widget build(BuildContext context) {
    return FamilySheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Family Options', style: TextStyle(color: FamilyRedesignColors.ink, fontSize: 22, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 12),
          if (isOwner) ...[
            _ActionTile(
              icon: Icons.admin_panel_settings_rounded,
              title: 'Set admins',
              subtitle: 'Current admins $adminCount/$adminCapacity. Capacity grows with family level.',
              onTap: onSetAdmins,
            ),
            _ActionTile(
              icon: Icons.delete_forever_rounded,
              title: 'Disband family',
              subtitle: 'Owner only. Members will be released from this family.',
              danger: true,
              onTap: onDisband,
            ),
          ] else
            _ActionTile(
              icon: Icons.logout_rounded,
              title: 'Exit family',
              subtitle: 'Everyone except the owner can exit family.',
              onTap: onExit,
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.danger = false});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? FamilyRedesignColors.coral : FamilyRedesignColors.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: FamilyRedesignColors.page, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: FamilyRedesignColors.soft, fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: FamilyRedesignColors.soft),
          ],
        ),
      ),
    );
  }
}
