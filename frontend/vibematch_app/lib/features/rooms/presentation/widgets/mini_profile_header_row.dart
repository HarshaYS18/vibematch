import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'mini_profile_decoration.dart';
import 'room_theme.dart';

class MiniProfileHeaderRow extends StatelessWidget {
  const MiniProfileHeaderRow({
    super.key,
    required this.user,
    required this.isSelf,
    required this.showAdminMenu,
    required this.onMentionTap,
    required this.onReportTap,
    required this.onSetAdminTap,
    required this.onRemoveAdminTap,
  });

  final SeatUser user;
  final bool isSelf;
  final bool showAdminMenu;
  final VoidCallback onMentionTap;
  final VoidCallback onReportTap;
  final VoidCallback onSetAdminTap;
  final VoidCallback onRemoveAdminTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: showAdminMenu
                ? _MiniProfileMoreMenuButton(
                    user: user,
                    onSetAdminTap: onSetAdminTap,
                    onRemoveAdminTap: onRemoveAdminTap,
                    onReportTap: onReportTap,
                  )
                : _MiniProfileReportIconButton(onTap: onReportTap),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 46),
              child: Text(
                user.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RoomColors.plum,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          if (!isSelf)
            Align(
              alignment: Alignment.centerRight,
              child: MiniProfileCornerButton(
                icon: Icons.alternate_email_rounded,
                color: RoomColors.aqua,
                size: 32,
                iconSize: 17,
                onTap: onMentionTap,
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniProfileReportIconButton extends StatelessWidget {
  const _MiniProfileReportIconButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MiniProfileCornerButton(
      icon: Icons.report_gmailerrorred_rounded,
      color: RoomColors.coral,
      size: 32,
      iconSize: 17,
      onTap: onTap,
    );
  }
}

class _MiniProfileMoreMenuButton extends StatelessWidget {
  const _MiniProfileMoreMenuButton({
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
    final canRemoveAdmin = user.isRoomAdmin && !user.isHost;

    return PopupMenuButton<String>(
      tooltip: 'More',
      offset: const Offset(0, 34),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onSelected: (value) {
        if (value == 'set_admin') onSetAdminTap();
        if (value == 'remove_admin') onRemoveAdminTap();
        if (value == 'report') onReportTap();
      },
      itemBuilder: (context) => [
        if (canRemoveAdmin)
          const PopupMenuItem<String>(
            value: 'remove_admin',
            child: _MiniProfileMenuRow(
              icon: Icons.shield_moon_rounded,
              color: RoomColors.coral,
              label: 'Remove admin',
            ),
          )
        else if (!user.isRoomAdmin && !user.isHost)
          const PopupMenuItem<String>(
            value: 'set_admin',
            child: _MiniProfileMenuRow(
              icon: Icons.shield_rounded,
              color: RoomColors.aqua,
              label: 'Set as admin',
            ),
          ),
        const PopupMenuItem<String>(
          value: 'report',
          child: _MiniProfileMenuRow(
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

class _MiniProfileMenuRow extends StatelessWidget {
  const _MiniProfileMenuRow({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 9),
        Text(
          label,
          style: const TextStyle(
            color: RoomColors.plum,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
