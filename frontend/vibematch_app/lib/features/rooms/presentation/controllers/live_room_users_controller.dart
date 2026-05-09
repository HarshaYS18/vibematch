import 'package:flutter/material.dart';

import '../../data/live_room_media_signaling_service.dart';
import '../live_room_models.dart';

class LiveRoomUsersController {
  const LiveRoomUsersController();

  List<SeatUser> buildAllRoomUsers({
    required List<SeatUser> seatedUsers,
    required List<SeatUser> fallbackRoomUsers,
    required List<SeatUser> inviteUsers,
    required bool Function(String userId) isUserRemoved,
  }) {
    final users = <SeatUser>[];
    final ids = <String>{};
    final snapshot = LiveRoomMediaSignalingService.instance.roomSnapshot.value;

    void addUser(SeatUser user) {
      if (isUserRemoved(user.id)) return;
      if (ids.add(user.id)) users.add(user);
    }

    if (snapshot != null) {
      for (final peer in snapshot.peers) {
        final existing = seatedUsers.firstWhereOrNull((user) => user.id == peer.userId);
        addUser(
          existing ??
              SeatUser(
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
              ),
        );
      }
      return users;
    }

    for (final user in seatedUsers) {
      addUser(user);
    }

    return users;
  }

  List<SeatUser> buildRoomAdmins(List<SeatUser> users) {
    return users.where((user) => user.isHost || user.isRoomAdmin).toList();
  }

  List<SeatUser> buildAvailableAdminUsers(List<SeatUser> users) {
    return users.where((user) => !user.isHost && !user.isRoomAdmin).toList();
  }

  List<SeatUser> buildSeatInviteUsers({
    required List<SeatUser> allRoomUsers,
    required List<SeatUser> seatedUsers,
    String currentUserId = '',
  }) {
    final seatedIds = seatedUsers.map((user) => user.id).toSet();
    return allRoomUsers
        .where((user) => user.id != currentUserId && !seatedIds.contains(user.id))
        .toList();
  }

  SeatUser resolveUserFromChatEntry({
    required ChatEntry entry,
    required List<SeatUser> allRoomUsers,
  }) {
    final senderId = entry.senderId;
    if (senderId == null) {
      return SeatUser(
        id: 'unknown_sender',
        name: entry.senderName,
        roleLabel: 'Member',
        familyName: '',
        relationshipText: '',
        vipLevel: entry.vipLevel,
        sendingLevel: entry.sendingLevel,
        receivingLevel: entry.receivingLevel,
        sentExp: 0,
        receivedExp: 0,
        medals: const [],
        avatarColors: const [],
      );
    }

    return allRoomUsers.firstWhere(
      (item) => item.id == senderId,
      orElse: () => SeatUser(
        id: senderId,
        name: entry.senderName,
        roleLabel: 'Member',
        familyName: '',
        relationshipText: '',
        vipLevel: entry.vipLevel,
        sendingLevel: entry.sendingLevel,
        receivingLevel: entry.receivingLevel,
        sentExp: 0,
        receivedExp: 0,
        medals: const [],
        avatarColors: const [],
      ),
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
