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

  String get _normalizedRoleLabel => user.roleLabel.trim().toLowerCase();

  bool get _isChannelHost {
    final label = _normalizedRoleLabel;
    return user.isHost || label == 'host' || label.contains('channel host');
  }

  bool get _isChannelAdmin {
    final label = _normalizedRoleLabel;
    return !_isChannelHost && (user.isRoomAdmin || label == 'admin' || label == 'channel admin' || label == 'room admin' || label == 'administrator');
  }

  RoleBadge? get _officialRoleBadge {
    final id = user.id.trim().toLowerCase();
    final label = _normalizedRoleLabel;

    if (_isChannelAdmin || _isChannelHost) return null;

    if (id == 'founder_owner' || id == 'super_owner' || id == 'user_6922022') return RoleBadge.fromRole('founder_owner');
    if (id == 'owner') return RoleBadge.fromRole('owner');
    if (id == 'superadmin' || id == 'super_admin') return RoleBadge.fromRole('superadmin');
    if (id == 'admin') return RoleBadge.fromRole('admin');
    if (id == 'agency_owner') return RoleBadge.fromRole('agency_owner');
    if (id == 'agency_member' || id == 'host') return RoleBadge.fromRole('host');

    if (label == 'official' || label.contains('super owner') || label.contains('founder') || label == 'owner') return RoleBadge.fromRole('owner');
    if (label == 'executive' || label.contains('super admin') || label.contains('superadmin')) return RoleBadge.fromRole('superadmin');
    if (label == 'associate' || label == 'app admin' || label == 'official admin') return RoleBadge.fromRole('admin');
    if (label == 'agency' || label.contains('agency owner')) return RoleBadge.fromRole('agency_owner');
    if (label == 'host' || label.contains('agency host')) return RoleBadge.fromRole('host');

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final officialRoleBadge = _officialRoleBadge;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        if (officialRoleBadge != null)
          OfficialRoleBadgePill(badge: officialRoleBadge, compact: true)
        else if (_isChannelHost)
          const MiniProfileMetaPill(icon: Icons.workspace_premium_rounded, label: 'Channel Host', color: RoomColors.gold)
        else if (_isChannelAdmin)
          const MiniProfileMetaPill(icon: Icons.admin_panel_settings_rounded, label: 'Admin', color: RoomColors.aqua),
        if (user.familyName.trim().isNotEmpty)
          MiniProfileFamilyBadge(
            familyName: user.familyName,
            familyLevel: user.familyLevel,
            onTap: onFamilyTap,
          ),
        if (user.age != null) MiniProfileGenderAgePill(user: user),
      ],
    );
  }
}

class MiniProfileGenderAgePill extends StatelessWidget {
  const MiniProfileGenderAgePill({super.key, required this.user});

  final SeatUser user;

  @override
  Widget build(BuildContext context) {
    final age = user.age;
    if (age == null) return const SizedBox.shrink();
    return MiniProfileMetaPill(
      icon: user.gender.icon,
      label: '$age',
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
      constraints: const BoxConstraints(maxWidth: 124),
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
