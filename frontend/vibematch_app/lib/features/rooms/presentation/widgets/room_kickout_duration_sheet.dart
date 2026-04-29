import 'package:flutter/material.dart';

import '../../data/room_moderation_repository.dart';
import '../live_room_models.dart';
import 'room_theme.dart';

class RoomKickoutDurationSheet extends StatelessWidget {
  const RoomKickoutDurationSheet({
    super.key,
    required this.user,
    required this.onDurationSelected,
  });

  final SeatUser user;
  final ValueChanged<RoomKickoutDuration> onDurationSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(width: 42),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: RoomColors.coral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: RoomColors.coral,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kick out ${user.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RoomColors.plum,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Choose how long this user should stay blocked from this room.',
                      style: TextStyle(
                        color: Color(0xFF7B6A86),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...RoomKickoutDuration.values.map(
            (duration) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.pop(context);
                  onDurationSelected(duration);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: duration == RoomKickoutDuration.forever
                        ? RoomColors.coral.withValues(alpha: 0.08)
                        : RoomColors.pearl,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: duration == RoomKickoutDuration.forever
                          ? RoomColors.coral.withValues(alpha: 0.24)
                          : RoomColors.softLine,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _durationColor(duration).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _durationIcon(duration),
                          color: _durationColor(duration),
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              duration.label,
                              style: const TextStyle(
                                color: RoomColors.plum,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              duration.description,
                              style: const TextStyle(
                                color: Color(0xFF7B6A86),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFFB3A9B9)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'This will be reflected in Room Settings → Blocked List. Backend permission checks and WebSocket removal will be connected as room backend matures.',
            style: TextStyle(
              color: Color(0xFF9A8FA3),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Color _durationColor(RoomKickoutDuration duration) {
    switch (duration) {
      case RoomKickoutDuration.oneHour:
        return RoomColors.gold;
      case RoomKickoutDuration.oneDay:
        return RoomColors.violet;
      case RoomKickoutDuration.forever:
        return RoomColors.coral;
    }
  }

  IconData _durationIcon(RoomKickoutDuration duration) {
    switch (duration) {
      case RoomKickoutDuration.oneHour:
        return Icons.timer_rounded;
      case RoomKickoutDuration.oneDay:
        return Icons.calendar_today_rounded;
      case RoomKickoutDuration.forever:
        return Icons.block_rounded;
    }
  }
}
