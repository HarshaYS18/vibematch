import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_theme.dart';

class RoomActionPage extends StatelessWidget {
  const RoomActionPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.cards = const <RoomActionCard>[],
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<RoomActionCard> cards;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RoomColors.pearl,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: RoomColors.plum,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: RoomColors.softLine),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [RoomColors.violet, RoomColors.aqua],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF6F627A),
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...cards.map(
            (card) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: card,
            ),
          ),
        ],
      ),
    );
  }
}

class RoomActionCard extends StatelessWidget {
  const RoomActionCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color = RoomColors.violet,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: RoomColors.softLine),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: RoomColors.plum,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Color(0xFF7B6A86),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF96899F),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoomRankingsPage extends StatelessWidget {
  const RoomRankingsPage({
    super.key,
    required this.title,
    required this.users,
    required this.sentRanking,
  });

  final String title;
  final List<SeatUser> users;
  final bool sentRanking;

  @override
  Widget build(BuildContext context) {
    final sorted = [...users]
      ..sort((a, b) {
        final left = sentRanking ? a.sentExp : a.receivedExp;
        final right = sentRanking ? b.sentExp : b.receivedExp;
        return right.compareTo(left);
      });

    return Scaffold(
      backgroundColor: RoomColors.pearl,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: RoomColors.plum,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: sorted.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final user = sorted[index];
          final value = sentRanking ? user.sentExp : user.receivedExp;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: RoomColors.softLine),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: index == 0
                        ? RoomColors.gold
                        : RoomColors.violet.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: index == 0 ? RoomColors.deep : RoomColors.violet,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: user.avatarColors),
                  ),
                  child: Text(
                    avatarLetter(user.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: RoomColors.plum,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user.familyName.trim().isEmpty
                            ? 'No family'
                            : user.familyName,
                        style: const TextStyle(
                          color: Color(0xFF7B6A86),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  compactNumber(value),
                  style: const TextStyle(
                    color: RoomColors.plum,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
