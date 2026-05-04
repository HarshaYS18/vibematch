import 'package:flutter/material.dart';

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
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Center(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 18),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: invitedUser.avatarColors),
                    boxShadow: [
                      BoxShadow(
                        color: invitedUser.avatarColors.first.withValues(alpha: 0.20),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    avatarLetter(invitedUser.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$inviterName invited you to take seat ${seatIndex + 1}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: RoomColors.plum,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          height: 1.18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Seat invitation for ${invitedUser.name} • auto hides in 15s',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF7B6A86),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _SeatInviteActionButton(
                  label: 'Reject',
                  color: const Color(0xFFE85D75),
                  background: const Color(0xFFFFEDF1),
                  onTap: onReject,
                ),
                const SizedBox(width: 6),
                _SeatInviteActionButton(
                  label: 'Accept',
                  color: const Color(0xFF129A63),
                  background: const Color(0xFFEAF9F1),
                  onTap: onAccept,
                ),
              ],
            ),
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
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
