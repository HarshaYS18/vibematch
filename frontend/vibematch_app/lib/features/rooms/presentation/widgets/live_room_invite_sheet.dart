import 'package:flutter/material.dart';

import '../../data/live_room_media_signaling_service.dart';
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

  List<SeatUser> get _realtimeUsers {
    final snapshot = LiveRoomMediaSignalingService.instance.roomSnapshot.value;
    final currentUserId = LiveRoomMediaSignalingService.instance.activeLoggedInSeatUser?.id;
    if (snapshot == null) return const <SeatUser>[];

    final seatedIds = snapshot.peers.where((peer) => peer.seatIndex != null).map((peer) => peer.userId).toSet();
    final seen = <String>{};

    return snapshot.peers.where((peer) {
      if (currentUserId != null && peer.userId == currentUserId) return false;
      if (seatedIds.contains(peer.userId)) return false;
      return seen.add(peer.userId);
    }).map((peer) {
      final existing = widget.users.firstWhereOrNull((user) => user.id == peer.userId);
      if (existing != null) {
        return existing.copyWith(selfMuted: !peer.micEnabled, adminMuted: peer.adminMuted);
      }
      return SeatUser(
        id: peer.userId,
        name: peer.displayName,
        roleLabel: 'Member',
        familyName: '',
        relationshipText: '',
        vipLevel: 1,
        sendingLevel: 1,
        receivingLevel: 1,
        sentExp: 0,
        receivedExp: 0,
        medals: const [],
        avatarColors: const [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
        selfMuted: !peer.micEnabled,
        adminMuted: peer.adminMuted,
      );
    }).toList();
  }

  List<SeatUser> get _sortedUsers {
    final sorted = [..._realtimeUsers];
    sorted.sort((a, b) {
      final idCompare = a.id.compareTo(b.id);
      if (idCompare != 0) return idCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  bool _isOnline(SeatUser user) {
    final snapshot = LiveRoomMediaSignalingService.instance.roomSnapshot.value;
    return snapshot?.peers.any((peer) => peer.userId == user.id) ?? false;
  }

  void _invite(SeatUser user) {
    final currentUserId = LiveRoomMediaSignalingService.instance.activeLoggedInSeatUser?.id;
    if (currentUserId != null && user.id == currentUserId) return;
    if (!_isOnline(user)) return;
    setState(() => _invitedIds.add(user.id));
    widget.onInvite(user);
  }

  @override
  Widget build(BuildContext context) {
    final users = _sortedUsers;

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
                        const LiveRoomInviteSectionLabel('In this room'),
                        ...users.map(_userRow),
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

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T item) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}
