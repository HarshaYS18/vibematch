import 'package:flutter/material.dart';

import '../live_room_models.dart';

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
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0D5CB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Invite to seat ${widget.seatIndex + 1}',
                    style: const TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${users.length} users',
                  style: const TextStyle(
                    color: Color(0xFF7B6A86),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: users.isEmpty
                  ? const Center(
                      child: Text(
                        'No users available to invite.',
                        style: TextStyle(
                          color: Color(0xFF7B6A86),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        if (onlineUsers.isNotEmpty) ...[
                          const _SectionLabel('Online'),
                          ...onlineUsers.map(_userRow),
                          const SizedBox(height: 8),
                        ],
                        if (otherUsers.isNotEmpty) ...[
                          const _SectionLabel('Users'),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: user.avatarColors),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  user.name.isEmpty ? '?' : user.name.characters.first.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ),
              if (_isOnline(user))
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF12C7B7),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user.id} · ${user.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  user.roleLabel.isEmpty ? 'Room user' : user.roleLabel,
                  style: const TextStyle(
                    color: Color(0xFF7B6A86),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: invited ? null : () => _invite(user),
            child: Text(invited ? 'Invited' : 'Invite'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF7B6A86),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
