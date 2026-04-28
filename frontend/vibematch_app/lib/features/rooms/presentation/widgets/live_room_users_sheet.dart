import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_user_list_sheet.dart';

class LiveRoomUsersSheet extends StatelessWidget {
  const LiveRoomUsersSheet({
    super.key,
    required this.users,
    required this.onUserTap,
  });

  final List<SeatUser> users;
  final ValueChanged<SeatUser> onUserTap;

  @override
  Widget build(BuildContext context) {
    return RoomUserListSheet(
      users: users,
      onUserTap: onUserTap,
    );
  }
}