import 'package:flutter/material.dart';

import '../../data/live_room_media_signaling_service.dart';
import '../live_room_models.dart';
import 'room_theme.dart';

class LiveRoomSeatInviteNotification extends StatelessWidget {
  const LiveRoomSeatInviteNotification({
    super.key,
    required this.inviterName,
    required this.invitedUser,
    required this.seatIndex,
    required this.onReject,
    required this.onAccept,
  });

  final String inviterName;
  final SeatUser invitedUser;
  final int seatIndex;
  final VoidCallback onReject;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final activeUserId = LiveRoomMediaSignalingService.instance.activeLoggedInSeatUser?.id;
    if (activeUserId != null && invitedUser.id != activeUserId) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.86),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: invitedUser.avatarColors),
                  boxShadow: [
                    BoxShadow(
                      color: invitedUser.avatarColors.first.withValues(
                        alpha: 0.22,
                      ),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  avatarLetter(invitedUser.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$inviterName has invited you to take seat ${seatIndex + 1}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RoomColors.plum,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _SeatInviteActionButton(
                      label: 'Reject',
                      color: const Color(0xFFE85D75),
                      background: const Color(0xFFFFEDF1),
                      onTap: onReject,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SeatInviteActionButton(
                      label: 'Accept',
                      color: const Color(0xFF129A63),
                      background: const Color(0xFFEAF9F1),
                      onTap: onAccept,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatInviteActionButton extends StatelessWidget {
  const _SeatInviteActionButton({
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.18),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
