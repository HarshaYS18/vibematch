import 'package:flutter/material.dart';

import '../../models/ranking_models.dart';

class RankingLuxuryTheme {
  static const bg = Color(0xFF080713);
  static const panel = Color(0xFF141121);
  static const gold = Color(0xFFFFD36E);
  static const text = Color(0xFFF9F2FF);
  static const muted = Color(0xFFB9ADC8);
  static const aqua = Color(0xFF19E6D2);
  static const pink = Color(0xFFFF5D9E);
}

class RankingTopBar extends StatelessWidget {
  const RankingTopBar({super.key, required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 6),
      child: Row(children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: RankingLuxuryTheme.text, size: 19),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: RankingLuxuryTheme.text, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.7)),
            const Text('Backend rankings only', style: TextStyle(color: RankingLuxuryTheme.muted, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: RankingLuxuryTheme.gold.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(color: RankingLuxuryTheme.gold.withValues(alpha: 0.32)),
          ),
          child: const Icon(Icons.leaderboard_rounded, color: RankingLuxuryTheme.gold, size: 18),
        ),
      ]),
    );
  }
}

class RankingPills extends StatelessWidget {
  const RankingPills({super.key, required this.value, required this.items, required this.onTap});
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: items.entries.map((entry) {
          final selected = entry.key == value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onTap(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? RankingLuxuryTheme.gold : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: selected ? RankingLuxuryTheme.gold : Colors.white.withValues(alpha: 0.10)),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: selected ? const Color(0xFF251538) : RankingLuxuryTheme.muted,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class RankingPodium extends StatelessWidget {
  const RankingPodium({super.key, required this.rows});
  final List<RankingEntry> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF221833), Color(0xFF3F245D), Color(0xFF171326)]),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: RankingLuxuryTheme.gold.withValues(alpha: 0.20)),
        boxShadow: [BoxShadow(color: RankingLuxuryTheme.gold.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, 18))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.emoji_events_rounded, color: RankingLuxuryTheme.gold, size: 22),
          SizedBox(width: 8),
          Text('Top Royal Board', style: TextStyle(color: RankingLuxuryTheme.text, fontSize: 17, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 14),
        Row(children: rows.map((row) => Expanded(child: RankingPodiumUser(row: row))).toList()),
      ]),
    );
  }
}

class RankingPodiumUser extends StatelessWidget {
  const RankingPodiumUser({super.key, required this.row});
  final RankingEntry row;

  @override
  Widget build(BuildContext context) {
    final color = row.rank == 1 ? RankingLuxuryTheme.gold : row.rank == 2 ? RankingLuxuryTheme.aqua : RankingLuxuryTheme.pink;
    return Column(children: [
      Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 18)]),
        child: _Avatar(user: row.user),
      ),
      const SizedBox(height: 8),
      Text(row.user.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: RankingLuxuryTheme.text, fontSize: 12, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text('#${row.rank} · ${row.scoreDisplay}', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
    ]);
  }
}

class RankingCard extends StatelessWidget {
  const RankingCard({super.key, required this.row});
  final RankingEntry row;

  @override
  Widget build(BuildContext context) {
    final rankColor = row.rank <= 3 ? RankingLuxuryTheme.gold : RankingLuxuryTheme.muted;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RankingLuxuryTheme.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: rankColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
          child: Text('#${row.rank}', style: TextStyle(fontWeight: FontWeight.w900, color: rankColor)),
        ),
        const SizedBox(width: 12),
        SizedBox(width: 42, height: 42, child: _Avatar(user: row.user)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(row.user.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: RankingLuxuryTheme.text, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text('VIP ${row.user.vipLevel} · SVIP ${row.user.svipLevel} · Sent Lv ${row.user.sendLevel} · Receive Lv ${row.user.receiveLevel}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: RankingLuxuryTheme.muted, fontWeight: FontWeight.w700)),
        ])),
        Text(row.scoreDisplay, style: const TextStyle(fontWeight: FontWeight.w900, color: RankingLuxuryTheme.gold, fontSize: 15)),
      ]),
    );
  }
}

class RankingEmptyState extends StatelessWidget {
  const RankingEmptyState({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Text('No backend ranking entries yet', style: TextStyle(color: RankingLuxuryTheme.muted, fontWeight: FontWeight.w900)),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});
  final RankingUser user;

  @override
  Widget build(BuildContext context) {
    final avatar = user.avatarUrl;
    return CircleAvatar(
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      backgroundImage: avatar == null ? null : NetworkImage(avatar),
      child: avatar == null ? Text(user.initials, style: const TextStyle(color: RankingLuxuryTheme.text, fontWeight: FontWeight.w900)) : null,
    );
  }
}
