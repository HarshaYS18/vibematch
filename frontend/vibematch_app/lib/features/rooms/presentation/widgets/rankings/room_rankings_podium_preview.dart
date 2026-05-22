import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import '../chat_vip_badge.dart';
import 'room_rankings_models.dart';

class RoomRankingsPodiumPreview extends StatelessWidget {
  const RoomRankingsPodiumPreview({
    super.key,
    required this.entries,
    required this.accentColor,
  });

  final List<RoomRankingEntry> entries;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: SizedBox(
        height: 184,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 48),
                child: _PodiumUser(
                  entry: second,
                  height: 118,
                  rank: 2,
                  accentColor: accentColor,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _PodiumUser(
                entry: first,
                height: 158,
                rank: 1,
                accentColor: accentColor,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 54),
                child: _PodiumUser(
                  entry: third,
                  height: 116,
                  rank: 3,
                  accentColor: accentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PodiumUser extends StatelessWidget {
  const _PodiumUser({
    required this.entry,
    required this.height,
    required this.rank,
    required this.accentColor,
  });

  final RoomRankingEntry? entry;
  final double height;
  final int rank;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final rankColor = switch (rank) {
      1 => const Color(0xFFFFD166),
      2 => const Color(0xFFB7C2FF),
      _ => const Color(0xFFFF8FA3),
    };

    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(8, 9, 8, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            rankColor.withValues(alpha: 0.23),
            accentColor.withValues(alpha: 0.13),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: rankColor.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: rankColor.withValues(alpha: 0.13),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PodiumAvatar(
            entry: entry,
            rankColor: rankColor,
            size: rank == 1 ? 42 : 36,
          ),
          const SizedBox(height: 5),
          Text(
            '$rank',
            style: TextStyle(
              color: rankColor,
              fontSize: rank == 1 ? 23 : 19,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry?.user.name ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          ChatVipBadge(level: entry?.user.vipLevel ?? 0, showWhenZero: true),
        ],
      ),
    );
  }
}

class _PodiumAvatar extends StatelessWidget {
  const _PodiumAvatar({required this.entry, required this.rankColor, required this.size});

  final RoomRankingEntry? entry;
  final Color rankColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final user = entry?.user;
    if (user == null) {
      return _AvatarShell(
        size: size,
        rankColor: rankColor,
        child: Text(
          '?',
          style: TextStyle(color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.w900),
        ),
      );
    }
    final avatarUrl = user.avatarUrl?.trim();
    final fallback = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: user.avatarColors)),
      child: Text(
        avatarLetter(user.name),
        style: TextStyle(color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.w900),
      ),
    );
    return _AvatarShell(
      size: size,
      rankColor: rankColor,
      child: ClipOval(
        child: avatarUrl == null || avatarUrl.isEmpty
            ? fallback
            : Image.network(
                avatarUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
      ),
    );
  }
}

class _AvatarShell extends StatelessWidget {
  const _AvatarShell({required this.size, required this.rankColor, required this.child});

  final double size;
  final Color rankColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: rankColor.withValues(alpha: 0.70), width: 1.4),
      ),
      child: ClipOval(child: child),
    );
  }
}