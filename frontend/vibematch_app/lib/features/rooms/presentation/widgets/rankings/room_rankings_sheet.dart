import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../auth/data/auth_api_service.dart';
import '../../../../auth/models/current_user.dart';
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
  CurrentUser? _syncedCurrentUser = const AuthApiService().cachedUser;
  StreamSubscription<CurrentUser>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _userSubscription = AuthUserRealtimeService.instance.users.listen((user) {
      if (!mounted) return;
      setState(() => _syncedCurrentUser = user);
    });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _category.accentColor;
    final syncedUsers = widget.users.map(_syncCurrentProfile).toList(growable: false);
    final allEntries = _controller.buildMockEntries(
      users: syncedUsers,
      category: _category,
      period: _period,
    );
    final podiumEntries = allEntries.take(3).toList(growable: false);
    final listEntries = allEntries.skip(3).take(97).toList(growable: false);
    final currentEntry = _currentEntry(allEntries);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: RoomRankingsBackground(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              14,
              10,
              14,
              MediaQuery.paddingOf(context).bottom + 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(width: 44, color: Colors.white54),
                const SizedBox(height: 12),
                _RankingsHeader(
                  title: _category.title,
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
                    itemCount: listEntries.length + 1,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return RoomRankingsPodiumPreview(
                          entries: podiumEntries,
                          accentColor: accentColor,
                        );
                      }
                      final entry = listEntries[index - 1];
                      return RoomRankingEntryTile(
                        entry: entry,
                        accentColor: accentColor,
                        onTap: widget.onUserTap == null ? null : () => widget.onUserTap!(entry.user),
                      );
                    },
                  ),
                ),
                if (currentEntry != null && currentEntry.rank > 3) ...[
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

  SeatUser _syncCurrentProfile(SeatUser user) {
    final current = _syncedCurrentUser;
    if (current == null || user.id != 'user_${current.publicUserId}') {
      return user;
    }
    return user.copyWith(
      name: current.displayName ?? current.username ?? user.name,
      avatarUrl: current.avatarUrl,
      clearAvatarUrl: current.avatarUrl == null,
      vipLevel: current.vip.vipLevel,
      svipLevel: current.vip.svipLevel,
    );
  }
}

class _RankingsHeader extends StatelessWidget {
  const _RankingsHeader({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.onClose,
  });

  final String title;
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
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.20),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, color: accentColor, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
            ),
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
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}