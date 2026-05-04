import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import '../chat_vip_badge.dart';
import 'room_rankings_models.dart';

class RoomRankingEntryTile extends StatelessWidget {
  const RoomRankingEntryTile({
    super.key,
    required this.entry,
    required this.accentColor,
    this.onTap,
  });

  final RoomRankingEntry entry;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isTopThree = entry.rank <= 3;
    final rankColor = switch (entry.rank) {
      1 => const Color(0xFFFFD166),
      2 => const Color(0xFFB7C2FF),
      3 => const Color(0xFFFF8FA3),
      _ => Colors.white.withValues(alpha: 0.58),
    };

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isTopThree ? 0.13 : 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isTopThree ? rankColor.withValues(alpha: 0.38) : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isTopThree ? rankColor.withValues(alpha: 0.20) : Colors.white.withValues(alpha: 0.08),
                  border: Border.all(color: rankColor.withValues(alpha: isTopThree ? 0.60 : 0.20)),
                ),
                child: Text(
                  entry.displayRank,
                  style: TextStyle(
                    color: rankColor,
                    fontSize: entry.rank > 99 ? 10 : 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: entry.user.avatarColors),
                  boxShadow: [
                    BoxShadow(
                      color: entry.user.avatarColors.first.withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  avatarLetter(entry.user.name),
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
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
                            entry.user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 5),
                        ChatVipBadge(level: entry.user.vipLevel, showWhenZero: true),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.58), fontSize: 10.5, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    entry.scoreText,
                    style: TextStyle(color: accentColor, fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: 82,
                    child: Text(
                      entry.scoreLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 9.5, fontWeight: FontWeight.w800),
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
