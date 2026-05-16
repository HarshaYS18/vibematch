import 'package:flutter/material.dart';

import '../../../../../core/widgets/vm_gradient_name_text.dart';
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

  bool get _isChannelHost =>
      user.isHost || user.roleLabel.toLowerCase().contains('channel host');

  bool get _isChannelAdmin =>
      !_isChannelHost &&
      (user.isRoomAdmin || user.roleLabel.toLowerCase() == 'admin');

  String get _roomTag {
    if (_isChannelHost) return 'Channel Host';
    if (_isChannelAdmin) return 'Admin';
    return '';
  }

  List<Color> get _tagGradient {
    if (_isChannelHost) {
      return const [Color(0xFFFFD166), Color(0xFFC99A3B), Color(0xFFFF8A3D)];
    }
    if (_isChannelAdmin) {
      return const [Color(0xFF12C7B7), Color(0xFF4A9BFF), Color(0xFF6D5DF6)];
    }
    return const [RoomColors.aqua, RoomColors.violet];
  }

  Color get _tagShadowColor =>
      _isChannelHost ? RoomColors.gold : RoomColors.aqua;

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
          Positioned.fill(
            left: 42,
            right: isSelf ? 42 : 42,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (tag.isNotEmpty) ...[
                      _RoomRoleTag(
                        label: tag,
                        gradient: _tagGradient,
                        shadowColor: _tagShadowColor,
                      ),
                      const SizedBox(width: 6),
                    ],
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 176),
                      child: VmGradientNameText(
                        text: user.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        gradientColors: user.nameGradientColors,
                        style: const TextStyle(
                          color: RoomColors.plum,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (tag.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Opacity(
                        opacity: 0,
                        child: _RoomRoleTag(
                          label: tag,
                          gradient: _tagGradient,
                          shadowColor: _tagShadowColor,
                        ),
                      ),
                    ],
                  ],
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

class _RoomRoleTag extends StatelessWidget {
  const _RoomRoleTag({
    required this.label,
    required this.gradient,
    required this.shadowColor,
  });

  final String label;
  final List<Color> gradient;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.62),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.4,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
