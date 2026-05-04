import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'chat_vip_badge.dart';
import 'room_theme.dart';

class RoomContributionRankingsSheet extends StatefulWidget {
  const RoomContributionRankingsSheet({
    super.key,
    required this.roomName,
    required this.users,
    this.onUserTap,
  });

  final String roomName;
  final List<SeatUser> users;
  final ValueChanged<SeatUser>? onUserTap;

  @override
  State<RoomContributionRankingsSheet> createState() => _RoomContributionRankingsSheetState();
}

class _RoomContributionRankingsSheetState extends State<RoomContributionRankingsSheet> {
  RoomContributionPeriod _period = RoomContributionPeriod.today;

  @override
  Widget build(BuildContext context) {
    final rankedUsers = _rankedUsers;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.68),
      padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.paddingOf(context).bottom + 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(width: 44),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(colors: [RoomColors.gold, RoomColors.coral]),
                  boxShadow: [
                    BoxShadow(
                      color: RoomColors.gold.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Room Contributions',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: RoomColors.plum, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.roomName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF82758E), fontSize: 11.5, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              RoundRoomButton(
                icon: Icons.close_rounded,
                onTap: () => Navigator.pop(context),
                color: RoomColors.plum,
                background: RoomColors.pearl,
                size: 34,
                iconSize: 18,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PeriodChip(
                  label: 'Today',
                  selected: _period == RoomContributionPeriod.today,
                  onTap: () => setState(() => _period = RoomContributionPeriod.today),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PeriodChip(
                  label: 'This Week',
                  selected: _period == RoomContributionPeriod.thisWeek,
                  onTap: () => setState(() => _period = RoomContributionPeriod.thisWeek),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: RoomColors.pearl,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: RoomColors.softLine),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text('Rank', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w900)),
                ),
                Text('Contribution', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: rankedUsers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final user = rankedUsers[index];
                final score = _scoreFor(user);
                return _ContributionRankTile(
                  rank: index + 1,
                  user: user,
                  score: score,
                  onTap: widget.onUserTap == null
                      ? null
                      : () => widget.onUserTap!(user),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Backend later: GET /rooms/{roomId}/rankings/contributions?period=today|week',
            style: TextStyle(color: RoomColors.plum.withValues(alpha: 0.50), fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  List<SeatUser> get _rankedUsers {
    final users = List<SeatUser>.from(widget.users);
    users.sort((a, b) => _scoreFor(b).compareTo(_scoreFor(a)));
    return users;
  }

  int _scoreFor(SeatUser user) {
    final base = user.sentExp + (user.receivedExp ~/ 2) + (user.vipLevel * 250);
    switch (_period) {
      case RoomContributionPeriod.today:
        return (base * 0.13).round() + (user.sendingLevel * 18);
      case RoomContributionPeriod.thisWeek:
        return (base * 0.46).round() + (user.receivingLevel * 42);
    }
  }
}

enum RoomContributionPeriod { today, thisWeek }

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected ? const LinearGradient(colors: [RoomColors.violet, RoomColors.aqua]) : null,
            color: selected ? null : RoomColors.pearl,
            border: Border.all(color: selected ? Colors.transparent : RoomColors.softLine),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : RoomColors.plum,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _ContributionRankTile extends StatelessWidget {
  const _ContributionRankTile({
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
