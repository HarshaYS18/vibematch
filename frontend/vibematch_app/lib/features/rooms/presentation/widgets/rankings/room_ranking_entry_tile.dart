import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import '../chat_vip_badge.dart';
import '../economy/gold_coin_icon.dart';
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

  bool get _showsCoinIcon => entry.scoreLabel == 'coin';

  @override
  Widget build(BuildContext context) {
    final rankColor = Colors.white.withValues(alpha: 0.62);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(color: rankColor.withValues(alpha: 0.20)),
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
              _RankingAvatar(user: entry.user),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    ChatVipBadge(level: entry.user.vipLevel, showWhenZero: true),
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
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _showsCoinIcon
                          ? const GoldCoinIcon(size: 12)
                          : Text(
                              entry.scoreLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.50),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
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

class _RankingAvatar extends StatelessWidget {
  const _RankingAvatar({required this.user});

  final SeatUser user;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl?.trim();
    final fallback = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: user.avatarColors)),
      child: Text(
        avatarLetter(user.name),
        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
      ),
    );
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: user.avatarColors.first.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: avatarUrl == null || avatarUrl.isEmpty
            ? fallback
            : Image.network(
                avatarUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
      ),
    );
  }
}