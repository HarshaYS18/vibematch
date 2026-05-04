import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'rankings/contribution/chatroom_contribution_rankings_sheet.dart';
import 'rankings/room_rankings_models.dart';

class RoomContributionRankingsSheet extends StatelessWidget {
  const RoomContributionRankingsSheet({
    super.key,
    required this.roomName,
    required this.users,
    this.roomPublicId = 'unknown_room',
    this.initialCategory = RoomRankingCategory.sent,
    this.initialPeriod = RoomRankingPeriod.daily,
    this.onUserTap,
  });

  final String roomName;
  final List<SeatUser> users;
  final String roomPublicId;
  final RoomRankingCategory initialCategory;
  final RoomRankingPeriod initialPeriod;
  final ValueChanged<SeatUser>? onUserTap;

  @override
  Widget build(BuildContext context) {
    return ChatroomContributionRankingsSheet(
      roomPublicId: roomPublicId,
      roomName: roomName,
      users: users,
      initialPeriod: initialPeriod == RoomRankingPeriod.weekly ? RoomRankingPeriod.weekly : RoomRankingPeriod.daily,
      onUserTap: onUserTap,
    );
  }
}
