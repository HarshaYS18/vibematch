import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'mini_profile_family_badge.dart';
import 'room_theme.dart';

class MiniProfileMetaRow extends StatelessWidget {
  const MiniProfileMetaRow({
    super.key,
    required this.user,
    required this.onFamilyTap,
  });

  final SeatUser user;
  final VoidCallback onFamilyTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        if (user.roleLabel.isNotEmpty)
          const SizedBox.shrink(),
        if (user.roleLabel.isNotEmpty)
          MiniProfileMetaPill(icon: Icons.shield_rounded, label: user.roleLabel),
        if (user.familyName.trim().isNotEmpty)
          MiniProfileFamilyBadge(
            familyName: user.familyName,
            familyLevel: user.familyLevel,
            onTap: onFamilyTap,
          ),
        MiniProfileGenderAgePill(user: user),
      ],
    );
  }
}

class MiniProfileGenderAgePill extends StatelessWidget {
  const MiniProfileGenderAgePill({super.key, required this.user});

  final SeatUser user;

  @override
  Widget build(BuildContext context) {
    final label = user.age == null ? 'Age hidden' : '${user.age}';
    return MiniProfileMetaPill(
      icon: user.gender.icon,
      label: label,
      color: user.gender.color,
    );
  }
}

class MiniProfileMetaPill extends StatelessWidget {
  const MiniProfileMetaPill({
    super.key,
    required this.icon,
    required this.label,
    this.color = RoomColors.plum,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 104),
      child: Container(
        height: 21,
        padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 0),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 10.5),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 9.0,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
