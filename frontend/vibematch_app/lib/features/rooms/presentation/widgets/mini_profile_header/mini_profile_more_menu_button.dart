import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import '../room_theme.dart';
import 'mini_profile_menu_row.dart';

class MiniProfileMoreMenuButton extends StatelessWidget {
  const MiniProfileMoreMenuButton({
    super.key,
    required this.user,
    required this.onSetAdminTap,
    required this.onRemoveAdminTap,
    required this.onReportTap,
  });

  final SeatUser user;
  final VoidCallback onSetAdminTap;
  final VoidCallback onRemoveAdminTap;
  final VoidCallback onReportTap;

  @override
  Widget build(BuildContext context) {
    final canRemoveChannelAdmin = user.isRoomAdmin && !user.isHost;

    return PopupMenuButton<String>(
      tooltip: 'More',
      offset: const Offset(0, 34),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onSelected: (value) {
        if (value == 'set_channel_admin') onSetAdminTap();
        if (value == 'remove_channel_admin') onRemoveAdminTap();
        if (value == 'report') onReportTap();
      },
      itemBuilder: (context) => [
        if (canRemoveChannelAdmin)
          const PopupMenuItem<String>(
            value: 'remove_channel_admin',
            child: MiniProfileMenuRow(
              icon: Icons.shield_moon_rounded,
              color: RoomColors.coral,
              label: 'Remove Channel Admin',
            ),
          )
        else if (!user.isRoomAdmin && !user.isHost)
          const PopupMenuItem<String>(
            value: 'set_channel_admin',
            child: MiniProfileMenuRow(
              icon: Icons.shield_rounded,
              color: RoomColors.aqua,
              label: 'Set as Channel Admin',
            ),
          ),
        const PopupMenuItem<String>(
          value: 'report',
          child: MiniProfileMenuRow(
            icon: Icons.report_gmailerrorred_rounded,
            color: RoomColors.coral,
            label: 'Report',
          ),
        ),
      ],
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: RoomColors.plum.withValues(alpha: 0.07),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.more_horiz_rounded, color: RoomColors.plum, size: 20),
      ),
    );
  }
}
