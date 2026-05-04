import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import '../chat_vip_badge.dart';
import '../room_theme.dart';

class ContributionRankTile extends StatelessWidget {
  const ContributionRankTile({
    super.key,
    required this.rank,
    required this.user,
    required this.score,
    this.onTap,
  });

  final int rank;
  final SeatUser user;
  final int score;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isTopThree = rank <= 3;
    final rankColor = switch (rank) {
      1 => RoomColors.gold,
      2 => RoomColors.aqua,
      3 => RoomColors.coral,
      _ => const Color(0xFF8C7B99),
    };

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isTopThree ? rankColor.withValues(alpha: 0.10) : RoomColors.pearl,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isTopThree ? rankColor.withValues(alpha: 0.22) : RoomColors.softLine),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isTopThree ? rankColor : Colors.white,
                  border: Border.all(color: isTopThree ? Colors.transparent : RoomColors.softLine),
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: isTopThree ? Colors.white : RoomColors.plum,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: user.avatarColors),
                    boxShadow: [BoxShadow(color: user.avatarColors.first.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 6))],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    avatarLetter(user.name),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: RoomColors.plum, fontSize: 13, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 5),
                        ChatVipBadge(level: user.vipLevel, showWhenZero: true),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.roleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF8C7B99), fontSize: 10.5, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    compactNumber(score),
                    style: const TextStyle(color: RoomColors.plum, fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'points',
                    style: TextStyle(color: Color(0xFF8C7B99), fontSize: 9.5, fontWeight: FontWeight.w800),
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
