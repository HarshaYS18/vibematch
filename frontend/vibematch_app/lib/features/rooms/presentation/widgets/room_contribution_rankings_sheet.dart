import 'package:flutter/material.dart';

import '../controllers/room_contribution_rankings_controller.dart';
import '../live_room_models.dart';
import 'room_contribution_rankings/contribution_period_chip.dart';
import 'room_contribution_rankings/contribution_rank_tile.dart';
import 'room_contribution_rankings/contribution_rankings_backend_hint.dart';
import 'room_contribution_rankings/contribution_rankings_header.dart';
import 'room_contribution_rankings/contribution_rankings_table_header.dart';
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
  final RoomContributionRankingsController _controller =
      const RoomContributionRankingsController();

  RoomContributionPeriod _period = RoomContributionPeriod.today;

  @override
  Widget build(BuildContext context) {
    final rankedUsers = _controller.rankedUsers(
      users: widget.users,
      period: _period,
    );

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
          RoomContributionRankingsHeader(
            roomName: widget.roomName,
            onClose: () => Navigator.pop(context),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ContributionPeriodChip(
                  label: 'Today',
                  selected: _period == RoomContributionPeriod.today,
                  onTap: () => setState(() => _period = RoomContributionPeriod.today),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ContributionPeriodChip(
                  label: 'This Week',
                  selected: _period == RoomContributionPeriod.thisWeek,
                  onTap: () => setState(() => _period = RoomContributionPeriod.thisWeek),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const ContributionRankingsTableHeader(),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: rankedUsers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final user = rankedUsers[index];
                final score = _controller.scoreFor(user, _period);
                return ContributionRankTile(
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
          const ContributionRankingsBackendHint(),
        ],
      ),
    );
  }
}
