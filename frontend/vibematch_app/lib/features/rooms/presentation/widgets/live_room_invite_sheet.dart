import 'package:flutter/material.dart';

import '../../../social/models/social_user.dart';
import '../../../social/widgets/friends_invite_sheet.dart';
import '../live_room_models.dart';

class LiveRoomInviteSheet extends StatelessWidget {
  const LiveRoomInviteSheet({
    super.key,
    required this.seatIndex,
    required this.users,
    required this.onInvite,
  });

  final int seatIndex;
  final List<SeatUser> users;
  final ValueChanged<SeatUser> onInvite;

  @override
  Widget build(BuildContext context) {
    return FriendsInviteSheet(
      title: 'Invite to seat ${seatIndex + 1}',
      onInvite: (friend) {
        onInvite(_toSeatUser(friend));
      },
    );
  }

  SeatUser _toSeatUser(SocialUser friend) {
    final fallback = users.where((user) => user.id == friend.id).firstOrNull;
    if (fallback != null) return fallback;

    return SeatUser(
      id: friend.id,
      name: friend.displayName,
      roleLabel: 'Friend',
      familyName: '',
      relationshipText: 'Friend',
      vipLevel: 0,
      sendingLevel: 0,
      receivingLevel: 0,
      sentExp: 0,
      receivedExp: 0,
      medals: const [],
      avatarColors: friend.colors,
    );
  }
}
