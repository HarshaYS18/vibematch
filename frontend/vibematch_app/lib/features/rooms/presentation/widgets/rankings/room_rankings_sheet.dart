import 'package:flutter/material.dart';

import '../../controllers/room_rankings_controller.dart';
import '../../live_room_models.dart';
import '../room_theme.dart';
import 'room_ranking_category_tabs.dart';
import 'room_ranking_entry_tile.dart';
import 'room_ranking_period_tabs.dart';
import 'room_rankings_background.dart';
import 'room_rankings_models.dart';
import 'room_rankings_podium_preview.dart';

class RoomRankingsSheet extends StatefulWidget {
  const RoomRankingsSheet({
    super.key,
    required this.roomPublicId,
    required this.roomName,
    required this.users,
    this.currentUserId,
    this.initialCategory = RoomRankingCategory.wealth,
    this.initialPeriod = RoomRankingPeriod.daily,
    this.onUserTap,
  });

  final String roomPublicId;
  final String roomName;
  final List<SeatUser> users;
  final String? currentUserId;
  final RoomRankingCategory initialCategory;
  final RoomRankingPeriod initialPeriod;
  final ValueChanged<SeatUser>? onUserTap;

  @override
  State<RoomRankingsSheet> createState() => _RoomRankingsSheetState();
}

class _RoomRankingsSheetState extends State<RoomRankingsSheet> {
  final RoomRankingsController _controller = const RoomRankingsController();

  late RoomRankingCategory _category = widget.initialCategory;
  late RoomRankingPeriod _period = widget.initialPeriod;

  @override
  Widget build(BuildContext context) {
    final accentColor = _category.accentColor;
    final allEntries = _controller.buildMockEntries(
      users: widget.users,
      category: _category,
      period: _period,
    );
    final topEntries = allEntries.take(100).toList(growable: false);
    final currentEntry = _currentEntry(allEntries);
    final backendPath = _controller.backendPath(
      roomPublicId: widget.roomPublicId,
      category: _category,
      period: _period,
    );

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
                _RankingsHeader(
                  title: _category.title,
                  roomName: widget.roomName,
                  icon: _category.icon,
                  accentColor: accentColor,
                  onClose: () => Navigator.pop(context),
                ),
                const SizedBox(height: 14),
                RoomRankingCategoryTabs(
                  selectedCategory: _category,
                  onChanged: (category) => setState(() => _category = category),
                ),
                const SizedBox(height: 10),
                RoomRankingPeriodTabs(
                  selectedPeriod: _period,
                  accentColor: accentColor,
                  onChanged: (period) => setState(() => _period = period),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(bottom: currentEntry == null ? 8 : 86),
                    itemCount: topEntries.length + 2,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return RoomRankingsPodiumPreview(entries: allEntries, accentColor: accentColor);
                      }
                      if (index == topEntries.length + 1) {
                        return Text(
                          'Backend later: GET $backendPath',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.42), fontSize: 9.5, fontWeight: FontWeight.w700),
                        );
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
    final currentUserId = widget.currentUserId;
    if (currentUserId != null && currentUserId.trim().isNotEmpty) {
      for (final entry in entries) {
        if (entry.user.id == currentUserId) return entry;
      }
    }
    for (final entry in entries) {
      if (entry.user.isCurrentUser) return entry;
    }
    return entries.isEmpty ? null : entries.first;
  }
}

class _RankingsHeader extends StatelessWidget {
  const _RankingsHeader({
    required this.title,
    required this.roomName,
    required this.icon,
    required this.accentColor,
    required this.onClose,
  });

  final String title;
  final String roomName;
  final IconData icon;
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
          child: Icon(icon, color: accentColor, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.35),
              ),
              const SizedBox(height: 2),
              Text(
                roomName,
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
