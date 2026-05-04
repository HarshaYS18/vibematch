import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'live_room_invite_components.dart';

class LiveRoomInviteSheet extends StatefulWidget {
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
  State<LiveRoomInviteSheet> createState() => _LiveRoomInviteSheetState();
}

class _LiveRoomInviteSheetState extends State<LiveRoomInviteSheet> {
  final Set<String> _invitedIds = <String>{};

  List<SeatUser> get _sortedUsers {
    final sorted = [...widget.users];
    sorted.sort((a, b) {
      final aOnline = _isOnline(a);
      final bOnline = _isOnline(b);
      if (aOnline != bOnline) return aOnline ? -1 : 1;
      final idCompare = a.id.compareTo(b.id);
      if (idCompare != 0) return idCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  bool _isOnline(SeatUser user) {
    return user.id == 'riya' || user.id == 'akhil' || user.isHost || user.isRoomAdmin;
  }

  void _invite(SeatUser user) {
    setState(() => _invitedIds.add(user.id));
    widget.onInvite(user);
  }

  @override
  Widget build(BuildContext context) {
    final users = _sortedUsers;
    final onlineUsers = users.where(_isOnline).toList();
    final otherUsers = users.where((user) => !_isOnline(user)).toList();

    return FractionallySizedBox(
      heightFactor: 0.40,
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.paddingOf(context).bottom + 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LiveRoomInviteHandle(),
            const SizedBox(height: 12),
            LiveRoomInviteHeader(
              seatIndex: widget.seatIndex,
              userCount: users.length,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: users.isEmpty
                  ? const LiveRoomInviteEmptyState()
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        if (onlineUsers.isNotEmpty) ...[
                          const LiveRoomInviteSectionLabel('Online'),
                          ...onlineUsers.map(_userRow),
                          const SizedBox(height: 8),
                        ],
                        if (otherUsers.isNotEmpty) ...[
                          const LiveRoomInviteSectionLabel('Users'),
                          ...otherUsers.map(_userRow),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userRow(SeatUser user) {
    final invited = _invitedIds.contains(user.id);

    return LiveRoomInviteUserRow(
      user: user,
      isOnline: _isOnline(user),
      invited: invited,
      onInvite: () => _invite(user),
    );
  }
}
