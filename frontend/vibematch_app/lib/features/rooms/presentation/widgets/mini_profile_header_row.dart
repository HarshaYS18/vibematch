import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'mini_profile_decoration.dart';
import 'mini_profile_header/mini_profile_more_menu_button.dart';
import 'mini_profile_header/mini_profile_report_icon_button.dart';
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

  String get _roomTag {
    if (user.isHost || user.roleLabel.toLowerCase().contains('channel host')) return 'Channel Host';
    if (user.isRoomAdmin || user.roleLabel.toLowerCase() == 'admin') return 'Admin';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final tag = _roomTag;
    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: showAdminMenu
                ? MiniProfileMoreMenuButton(
                    user: user,
                    onSetAdminTap: onSetAdminTap,
                    onRemoveAdminTap: onRemoveAdminTap,
                    onReportTap: onReportTap,
                  )
                : MiniProfileReportIconButton(onTap: onReportTap),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 46),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (tag.isNotEmpty) ...[
                    Flexible(
                      flex: 0,
                      child: Container(
                        height: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: user.isHost ? RoomColors.gold.withValues(alpha: 0.20) : RoomColors.aqua.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: user.isHost ? RoomColors.gold.withValues(alpha: 0.42) : RoomColors.aqua.withValues(alpha: 0.38)),
                        ),
                        child: Text(
                          tag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: user.isHost ? RoomColors.gold : RoomColors.aqua,
                            fontSize: 9.8,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
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
                ],
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
