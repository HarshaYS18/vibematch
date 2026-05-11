import 'package:flutter/material.dart';

import '../../data/live_room_media_signaling_service.dart';
import '../../data/live_room_presence_repository.dart';
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
    final media = LiveRoomMediaSignalingService.instance;
    final snapshot = media.roomSnapshot.value;
    final presenceUsers = LiveRoomPresenceRepository.currentParticipantsForRoom(media.roomId);

    void addUser(SeatUser user) {
      if (user.id.trim().isEmpty) return;
      if (isUserRemoved(user.id)) return;
      if (ids.add(user.id)) users.add(user);
    }

    for (final user in presenceUsers) {
      addUser(user);
    }

    for (final user in seatedUsers) {
      final presenceUser = LiveRoomPresenceRepository.userByRoomUserId(user.id);
      addUser(_mergeSeatWithPresence(seatUser: user, presenceUser: presenceUser));
    }

    if (snapshot != null) {
      for (final peer in snapshot.peers) {
        final existingSeatUser = seatedUsers.firstWhereOrNull((user) => user.id == peer.userId);
        final presenceUser = LiveRoomPresenceRepository.userByRoomUserId(peer.userId);
        addUser(_seatUserFromPeer(peer: peer, baseUser: existingSeatUser ?? presenceUser));
      }
    }

    for (final user in fallbackRoomUsers) {
      final presenceUser = LiveRoomPresenceRepository.userByRoomUserId(user.id);
      addUser(_mergeSeatWithPresence(seatUser: user, presenceUser: presenceUser));
    }

    for (final user in inviteUsers) {
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
    return allRoomUsers.where((user) => user.id != currentUserId && !seatedIds.contains(user.id)).toList();
  }

  SeatUser resolveUserFromChatEntry({
    required ChatEntry entry,
    required List<SeatUser> allRoomUsers,
  }) {
    final senderId = entry.senderId;
    if (senderId == null) {
      return SeatUser(id: 'unknown_sender', name: entry.senderName, roleLabel: 'Member', familyName: '', relationshipText: '', vipLevel: entry.vipLevel, sendingLevel: entry.sendingLevel, receivingLevel: entry.receivingLevel, sentExp: 0, receivedExp: 0, medals: const [], avatarColors: const []);
    }

    return allRoomUsers.firstWhere(
      (item) => item.id == senderId,
      orElse: () => SeatUser(id: senderId, name: entry.senderName, roleLabel: 'Member', familyName: '', relationshipText: '', vipLevel: entry.vipLevel, sendingLevel: entry.sendingLevel, receivingLevel: entry.receivingLevel, sentExp: 0, receivedExp: 0, medals: const [], avatarColors: const []),
    );
  }

  SeatUser _seatUserFromPeer({required LiveMediaPeerSnapshot peer, SeatUser? baseUser}) {
    final displayName = peer.displayName.trim().isNotEmpty ? peer.displayName.trim() : (baseUser?.name ?? _fallbackDisplayNameForUserId(peer.userId));
    return SeatUser(
      id: peer.userId,
      name: displayName,
      roleLabel: baseUser?.roleLabel ?? 'Member',
      familyName: baseUser?.familyName ?? '',
      familyLevel: baseUser?.familyLevel ?? 'bronze',
      relationshipText: baseUser?.relationshipText ?? '',
      vipLevel: baseUser?.vipLevel ?? 0,
      svipLevel: baseUser?.svipLevel ?? 0,
      sendingLevel: baseUser?.sendingLevel ?? 1,
      receivingLevel: baseUser?.receivingLevel ?? 1,
      sentExp: baseUser?.sentExp ?? 0,
      receivedExp: baseUser?.receivedExp ?? 0,
      medals: baseUser?.medals ?? const [],
      avatarColors: baseUser?.avatarColors ?? const [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
      age: baseUser?.age,
      locationLabel: baseUser?.locationLabel,
      locationVisible: baseUser?.locationVisible ?? true,
      gender: baseUser?.gender ?? RoomUserGender.undisclosed,
      isCurrentUser: baseUser?.isCurrentUser ?? false,
      isHost: baseUser?.isHost ?? false,
      isRoomAdmin: baseUser?.isRoomAdmin ?? false,
      selfMuted: !peer.micEnabled,
      adminMuted: peer.adminMuted,
    );
  }

  SeatUser _mergeSeatWithPresence({required SeatUser seatUser, SeatUser? presenceUser}) {
    if (presenceUser == null) return seatUser;
    return SeatUser(
      id: seatUser.id,
      name: presenceUser.name,
      roleLabel: presenceUser.roleLabel,
      familyName: presenceUser.familyName,
      familyLevel: presenceUser.familyLevel,
      relationshipText: presenceUser.relationshipText,
      vipLevel: presenceUser.vipLevel,
      svipLevel: presenceUser.svipLevel,
      sendingLevel: presenceUser.sendingLevel,
      receivingLevel: presenceUser.receivingLevel,
      sentExp: presenceUser.sentExp,
      receivedExp: presenceUser.receivedExp,
      medals: presenceUser.medals,
      avatarColors: presenceUser.avatarColors,
      age: presenceUser.age,
      locationLabel: presenceUser.locationLabel,
      locationVisible: presenceUser.locationVisible,
      gender: presenceUser.gender,
      isCurrentUser: seatUser.isCurrentUser || presenceUser.isCurrentUser,
      isHost: presenceUser.isHost,
      isRoomAdmin: presenceUser.isRoomAdmin,
      selfMuted: seatUser.selfMuted,
      adminMuted: seatUser.adminMuted,
    );
  }

  String _fallbackDisplayNameForUserId(String userId) {
    final publicId = userId.startsWith('user_') ? userId.substring(5) : userId;
    return publicId.trim().isEmpty ? 'Vibe User' : 'User $publicId';
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
