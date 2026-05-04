import 'package:flutter/material.dart';

import 'room_profile_actions/leave_seat_icon.dart';
import 'room_profile_actions/room_profile_action_colors.dart';
import 'room_profile_actions/room_profile_action_item_data.dart';
import 'room_profile_actions/room_profile_action_tile.dart';

class RoomProfileActionRow extends StatelessWidget {
  const RoomProfileActionRow({
    super.key,
    required this.isSelf,
    required this.canModerate,
    required this.selfMuted,
    required this.adminMuted,
    required this.onLeaveAndLock,
    required this.onLeaveSeatOnly,
    required this.onSelfMuteToggle,
    required this.onAdminMuteToggle,
    this.onKickOutTap,
  });

  final bool isSelf;
  final bool canModerate;
  final bool selfMuted;
  final bool adminMuted;
  final VoidCallback onLeaveAndLock;
  final VoidCallback onLeaveSeatOnly;
  final VoidCallback onSelfMuteToggle;
  final VoidCallback onAdminMuteToggle;
  final VoidCallback? onKickOutTap;

  @override
  Widget build(BuildContext context) {
    final actions = <RoomProfileActionItemData>[
      if (isSelf)
        RoomProfileActionItemData(
          icon: const LeaveSeatIcon(color: RoomProfileActionColors.icon),
          label: 'Leave',
          onTap: onLeaveSeatOnly,
        ),
      if (canModerate && !isSelf)
        RoomProfileActionItemData(
          icon: const Icon(Icons.lock_rounded),
          label: 'Leave & Lock',
          onTap: onLeaveAndLock,
        ),
      if (canModerate && !isSelf)
        RoomProfileActionItemData(
          icon: const LeaveSeatIcon(color: RoomProfileActionColors.icon),
          label: 'Leave',
          onTap: onLeaveSeatOnly,
        ),
      if (canModerate && !isSelf && onKickOutTap != null)
        RoomProfileActionItemData(
          icon: const Icon(Icons.person_remove_alt_1_rounded),
          label: 'Kick out',
          onTap: onKickOutTap!,
        ),
      if (isSelf)
        RoomProfileActionItemData(
          icon: Icon(selfMuted ? Icons.mic_off_rounded : Icons.mic_rounded),
          label: selfMuted ? 'Turn On' : 'Turn Off',
          onTap: onSelfMuteToggle,
        )
      else if (canModerate)
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
}
