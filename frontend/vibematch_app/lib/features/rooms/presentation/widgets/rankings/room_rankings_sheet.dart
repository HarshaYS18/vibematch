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
    this.initialCategory = RoomRankingCategory.wealth,
    this.initialPeriod = RoomRankingPeriod.daily,
    this.onUserTap,
  });

  final String roomPublicId;
  final String roomName;
  final List<SeatUser> users;
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
    final entries = _controller.buildMockEntries(
      users: widget.users,
      category: _category,
      period: _period,
    );
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
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withValues(alpha: 0.18),
                        border: Border.all(color: accentColor.withValues(alpha: 0.42)),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.20),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(_category.icon, color: accentColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _category.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.35,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.roomName,
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
                        onTap: () => Navigator.pop(context),
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
                RoomRankingsPodiumPreview(entries: entries, accentColor: accentColor),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: entries.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return RoomRankingEntryTile(
                        entry: entry,
                        accentColor: accentColor,
                        onTap: widget.onUserTap == null ? null : () => widget.onUserTap!(entry.user),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Backend later: GET $backendPath',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.42), fontSize: 9.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
