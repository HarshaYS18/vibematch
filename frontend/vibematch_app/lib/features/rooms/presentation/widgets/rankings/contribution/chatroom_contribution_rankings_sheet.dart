import 'package:flutter/material.dart';

import '../../../controllers/room_rankings_controller.dart';
import '../../../live_room_models.dart';
import '../../room_theme.dart';
import '../room_ranking_entry_tile.dart';
import '../room_rankings_background.dart';
import '../room_rankings_models.dart';
import '../room_rankings_podium_preview.dart';

class ChatroomContributionRankingsSheet extends StatefulWidget {
  const ChatroomContributionRankingsSheet({
    super.key,
    required this.roomName,
    required this.users,
    this.roomPublicId = 'unknown_room',
    this.initialPeriod = RoomRankingPeriod.daily,
    this.onUserTap,
  });

  final String roomName;
  final List<SeatUser> users;
  final String roomPublicId;
  final RoomRankingPeriod initialPeriod;
  final ValueChanged<SeatUser>? onUserTap;

  @override
  State<ChatroomContributionRankingsSheet> createState() => _ChatroomContributionRankingsSheetState();
}

class _ChatroomContributionRankingsSheetState extends State<ChatroomContributionRankingsSheet> {
  static const List<RoomRankingPeriod> _periods = [
    RoomRankingPeriod.daily,
    RoomRankingPeriod.weekly,
  ];

  final RoomRankingsController _controller = const RoomRankingsController();
  late RoomRankingPeriod _period = _periods.contains(widget.initialPeriod) ? widget.initialPeriod : RoomRankingPeriod.daily;

  @override
  Widget build(BuildContext context) {
    const category = RoomRankingCategory.sent;
    final accentColor = category.accentColor;
    final roomScopedUsers = widget.users;
    final entries = _controller.buildMockEntries(
      users: roomScopedUsers,
      category: category,
      period: _period,
    );
    final topEntries = entries.take(100).toList(growable: false);
    final currentEntry = _currentEntry(entries);
    final backendPath = '/rooms/${widget.roomPublicId}/contributions?period=${_period.backendValue}';

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: RoomRankingsBackground(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.paddingOf(context).bottom + 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(width: 44, color: Colors.white54),
                const SizedBox(height: 12),
                _ContributionHeader(
                  roomName: widget.roomName,
                  period: _period,
                  accentColor: accentColor,
                  onClose: () => Navigator.pop(context),
                ),
                const SizedBox(height: 12),
                _ContributionPeriodTabs(
                  selectedPeriod: _period,
                  accentColor: accentColor,
                  onChanged: (period) => setState(() => _period = period),
                ),
                const SizedBox(height: 12),
                _RoomScopePill(
                  roomName: widget.roomName,
                  usersCount: roomScopedUsers.length,
                  backendPath: backendPath,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(bottom: currentEntry == null ? 8 : 86),
                    itemCount: topEntries.length + 1,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return RoomRankingsPodiumPreview(entries: entries, accentColor: accentColor);
                      }
                      final entry = topEntries[index - 1];
                      return RoomRankingEntryTile(
                        entry: entry,
                        accentColor: accentColor,
                        onTap: widget.onUserTap == null ? null : () => widget.onUserTap!(entry.user),
                      );
                    },
                  ),
                ),
                if (currentEntry != null) ...[
                  const SizedBox(height: 8),
                  RoomRankingEntryTile(
                    entry: currentEntry,
                    accentColor: accentColor,
                    onTap: widget.onUserTap == null ? null : () => widget.onUserTap!(currentEntry.user),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  RoomRankingEntry? _currentEntry(List<RoomRankingEntry> entries) {
    for (final entry in entries) {
      if (entry.user.isCurrentUser) return entry;
    }
    return entries.isEmpty ? null : entries.first;
  }
}

class _ContributionHeader extends StatelessWidget {
  const _ContributionHeader({
    required this.roomName,
    required this.period,
    required this.accentColor,
    required this.onClose,
  });

  final String roomName;
  final RoomRankingPeriod period;
  final Color accentColor;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor.withValues(alpha: 0.18),
            border: Border.all(color: accentColor.withValues(alpha: 0.42)),
            boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.20), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Icon(Icons.emoji_events_rounded, color: accentColor, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chatroom Contribution',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.35),
              ),
              const SizedBox(height: 2),
              Text(
                '${period.label} top contributors in this room',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.58), fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onClose,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoomScopePill extends StatelessWidget {
  const _RoomScopePill({
    required this.roomName,
    required this.usersCount,
    required this.backendPath,
  });

  final String roomName;
  final int usersCount;
  final String backendPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.meeting_room_rounded, color: RoomColors.gold, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$roomName only',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900),
                ),
              ),
              Text('$usersCount users', style: TextStyle(color: Colors.white.withValues(alpha: 0.58), fontSize: 10.5, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Backend later: GET $backendPath',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.34), fontSize: 9.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ContributionPeriodTabs extends StatelessWidget {
  const _ContributionPeriodTabs({
    required this.selectedPeriod,
    required this.accentColor,
    required this.onChanged,
  });

  final RoomRankingPeriod selectedPeriod;
  final Color accentColor;
  final ValueChanged<RoomRankingPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    const periods = [RoomRankingPeriod.daily, RoomRankingPeriod.weekly];

    return Row(
      children: periods.map((period) {
        final selected = selectedPeriod == period;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => onChanged(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: selected ? accentColor : Colors.white.withValues(alpha: 0.08),
                  border: Border.all(color: selected ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.10)),
                ),
                child: Text(
                  period.label,
                  style: TextStyle(
                    color: selected ? RoomColors.deep : Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
