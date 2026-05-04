import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'rankings/room_rankings_models.dart';
import 'rankings/room_rankings_sheet.dart';

class RoomContributionRankingsSheet extends StatelessWidget {
  const RoomContributionRankingsSheet({
    super.key,
    required this.roomName,
    required this.users,
    this.roomPublicId = 'unknown_room',
    this.initialCategory = RoomRankingCategory.wealth,
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
    return RoomRankingsSheet(
      roomPublicId: roomPublicId,
      roomName: roomName,
      users: users,
      initialCategory: initialCategory,
      initialPeriod: initialPeriod,
      onUserTap: onUserTap,
    );
  }
}
