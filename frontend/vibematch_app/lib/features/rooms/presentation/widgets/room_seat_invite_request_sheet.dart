import 'package:flutter/material.dart';

import 'room_theme.dart';

class RoomSeatInviteRequestSheet extends StatelessWidget {
  const RoomSeatInviteRequestSheet({
    super.key,
    required this.onDecline,
    required this.onAccept,
  });

  final VoidCallback onDecline;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 330),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFECE7F1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Seat invitation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: RoomColors.plum,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You’ve been invited to take the mic seat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF75687F),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.28,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _SeatInviteButton(
                        label: 'Decline',
                        background: const Color(0xFFFFEEF0),
                        foreground: RoomColors.coral,
                        border: const Color(0xFFFFCFD5),
                        onTap: onDecline,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SeatInviteButton(
                        label: 'Accept',
                        background: const Color(0xFFE8F8EF),
                        foreground: const Color(0xFF139A5C),
                        border: const Color(0xFFBEE8D1),
                        onTap: onAccept,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatInviteButton extends StatelessWidget {
  const _SeatInviteButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}