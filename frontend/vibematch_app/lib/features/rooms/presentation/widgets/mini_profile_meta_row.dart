import 'package:flutter/material.dart';

import '../../../auth/models/role_badge.dart';
import '../../../profile/presentation/widgets/official_role_badge_pill.dart';
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

  RoleBadge? get _roleBadge {
    final id = user.id.trim().toLowerCase();
    final label = user.roleLabel.trim().toLowerCase();

    if (id == 'founder_owner' || id == 'super_owner') return RoleBadge.fromRole('founder_owner');
    if (id == 'owner') return RoleBadge.fromRole('owner');
    if (id == 'superadmin' || id == 'super_admin') return RoleBadge.fromRole('superadmin');
    if (id == 'admin') return RoleBadge.fromRole('admin');
    if (id == 'coin_seller') return RoleBadge.fromRole('coin_seller');
    if (id == 'merchant' || id == 'reseller') return RoleBadge.fromRole('merchant');
    if (id == 'agency_owner') return RoleBadge.fromRole('agency_owner');
    if (id == 'agency_member' || id == 'host') return RoleBadge.fromRole('agency_member');

    if (label.contains('super owner') || label.contains('founder')) return RoleBadge.fromRole('founder_owner');
    if (label == 'owner' || label.contains(' official')) return RoleBadge.fromRole('owner');
    if (label.contains('super admin')) return RoleBadge.fromRole('superadmin');
    if (label == 'admin' || label.contains('administrator')) return RoleBadge.fromRole('admin');
    if (label.contains('coin seller')) return RoleBadge.fromRole('coin_seller');
    if (label.contains('merchant') || label.contains('reseller')) return RoleBadge.fromRole('merchant');
    if (label.contains('agency owner')) return RoleBadge.fromRole('agency_owner');
    if (label == 'host' || label.contains('channel host') || label.contains('agency member')) return RoleBadge.fromRole('agency_member');

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final roleBadge = _roleBadge;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        if (roleBadge != null)
          OfficialRoleBadgePill(badge: roleBadge, compact: true)
        else if (user.roleLabel.isNotEmpty && user.roleLabel.toLowerCase() != 'member')
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
