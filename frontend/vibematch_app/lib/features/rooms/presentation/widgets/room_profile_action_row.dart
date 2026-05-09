import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_profile_actions/leave_seat_icon.dart';
import 'room_profile_actions/room_profile_action_colors.dart';
import 'room_profile_actions/room_profile_action_item_data.dart';
import 'room_profile_actions/room_profile_action_tile.dart';

class RoomProfileActionRow extends StatelessWidget {
  const RoomProfileActionRow({
    super.key,
    required this.user,
    required this.currentUser,
    required this.selfMuted,
    required this.adminMuted,
    required this.onLeaveAndLock,
    required this.onLeaveSeatOnly,
    required this.onSelfMuteToggle,
    required this.onAdminMuteToggle,
    this.onKickOutTap,
  });

  final SeatUser user;
  final SeatUser currentUser;
  final bool selfMuted;
  final bool adminMuted;
  final VoidCallback onLeaveAndLock;
  final VoidCallback onLeaveSeatOnly;
  final VoidCallback onSelfMuteToggle;
  final VoidCallback onAdminMuteToggle;
  final VoidCallback? onKickOutTap;

  bool get _isSelf => user.id == currentUser.id;
  int get _viewerPower => _roomPower(currentUser);
  int get _targetPower => _roomPower(user);

  bool get _viewerIsOwner => _viewerPower >= 100;
  bool get _viewerIsAdmin => _viewerPower >= 90 && _viewerPower < 100;
  bool get _targetIsOwner => _targetPower >= 100;
  bool get _canModerateTarget {
    if (_isSelf) return false;
    if (_targetIsOwner) return false;
    if (_viewerIsOwner) return _targetPower < 100;
    if (_viewerIsAdmin) return _targetPower < 90;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final actions = <RoomProfileActionItemData>[
      if (_isSelf)
        RoomProfileActionItemData(
          icon: const LeaveSeatIcon(color: RoomProfileActionColors.icon),
          label: 'Leave',
          onTap: onLeaveSeatOnly,
        ),
      if (_canModerateTarget)
        RoomProfileActionItemData(
          icon: const Icon(Icons.lock_rounded),
          label: 'Leave & Lock',
          onTap: onLeaveAndLock,
        ),
      if (_canModerateTarget)
        RoomProfileActionItemData(
          icon: const LeaveSeatIcon(color: RoomProfileActionColors.icon),
          label: 'Leave',
          onTap: onLeaveSeatOnly,
        ),
      if (_canModerateTarget && onKickOutTap != null)
        RoomProfileActionItemData(
          icon: const Icon(Icons.person_remove_alt_1_rounded),
          label: 'Kick out',
          onTap: onKickOutTap!,
        ),
      if (_isSelf)
        RoomProfileActionItemData(
          icon: Icon(selfMuted ? Icons.mic_off_rounded : Icons.mic_rounded),
          label: selfMuted ? 'Turn On' : 'Turn Off',
          onTap: onSelfMuteToggle,
        )
      else if (_canModerateTarget)
        RoomProfileActionItemData(
          icon: Icon(adminMuted ? Icons.mic_rounded : Icons.mic_off_rounded),
          label: adminMuted ? 'Turn On' : 'Turn Off',
          onTap: onAdminMuteToggle,
        ),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 62,
      margin: const EdgeInsets.only(top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RoomProfileActionColors.divider.withValues(alpha: 0.85)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            Expanded(child: RoomProfileActionTile(data: actions[i])),
            if (i != actions.length - 1)
              Container(
                width: 1,
                height: 34,
                color: RoomProfileActionColors.divider,
              ),
          ],
        ],
      ),
    );
  }

  static int _roomPower(SeatUser user) {
    final role = user.roleLabel.toLowerCase();
    final isOwner = user.isHost ||
        user.id == 'user_6922022' ||
        user.id == 'founder_owner' ||
        role.contains('owner') ||
        role.contains('channel host') ||
        role == 'host';
    if (isOwner) return 100;

    final isAdmin = user.isRoomAdmin || role.contains('admin') || role.contains('administrator');
    if (isAdmin) return 90;

    return 0;
  }
}
