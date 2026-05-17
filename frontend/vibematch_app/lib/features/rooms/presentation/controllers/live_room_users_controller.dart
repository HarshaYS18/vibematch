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
    final usersByKey = <String, SeatUser>{};
    final rawIdToKey = <String, String>{};
    final media = LiveRoomMediaSignalingService.instance;
    final snapshot = media.roomSnapshot.value;
    final presenceUsers = LiveRoomPresenceRepository.currentParticipantsForRoom(
      media.roomId,
    );

    void rememberAlias(String rawId, String key) {
      final cleanRaw = rawId.trim();
      if (cleanRaw.isEmpty) return;
      rawIdToKey[cleanRaw] = key;
      rawIdToKey[_canonicalUserKey(cleanRaw)] = key;
    }

    String keyForUser(SeatUser user) {
      final cleanId = user.id.trim();
      if (cleanId.isEmpty) return '';
      final existing = rawIdToKey[cleanId] ?? rawIdToKey[_canonicalUserKey(cleanId)];
      if (existing != null) return existing;
      return _canonicalUserKey(cleanId);
    }

    void addUser(SeatUser user) {
      final cleanId = user.id.trim();
      if (cleanId.isEmpty) return;
      if (isUserRemoved(cleanId)) return;
      final key = keyForUser(user);
      if (key.isEmpty) return;
      rememberAlias(cleanId, key);
      final existing = usersByKey[key];
      usersByKey[key] = existing == null ? user : _mergeDuplicateUser(existing, user);
    }

    if (snapshot != null) {
      for (final peer in snapshot.peers) {
        final peerKey = _canonicalUserKey(peer.userId);
        rememberAlias(peer.userId, peerKey);
        final publicUserId = peer.publicUserId;
        if (publicUserId != null && publicUserId.trim().isNotEmpty) {
          rememberAlias(publicUserId, peerKey);
          rememberAlias('user_$publicUserId', peerKey);
          rememberAlias('${snapshot.roomId}_user_$publicUserId', peerKey);
        }
      }
    }

    for (final user in presenceUsers) {
      addUser(user);
    }

    for (final user in seatedUsers) {
      final presenceUser = LiveRoomPresenceRepository.userByRoomUserId(user.id);
      addUser(
        _mergeSeatWithPresence(seatUser: user, presenceUser: presenceUser),
      );
    }

    if (snapshot != null) {
      for (final peer in snapshot.peers) {
        final existingSeatUser = seatedUsers.firstWhereOrNull(
          (user) => keyForUser(user) == _canonicalUserKey(peer.userId),
        );
        final presenceUser = LiveRoomPresenceRepository.userByRoomUserId(
          peer.userId,
        );
        addUser(
          _seatUserFromPeer(
            peer: peer,
            baseUser: existingSeatUser ?? presenceUser,
          ),
        );
      }
    }

    for (final user in fallbackRoomUsers) {
      final presenceUser = LiveRoomPresenceRepository.userByRoomUserId(user.id);
      addUser(
        _mergeSeatWithPresence(seatUser: user, presenceUser: presenceUser),
      );
    }

    for (final user in inviteUsers) {
      addUser(user);
    }

    return usersByKey.values.toList(growable: false);
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
    final seatedKeys = seatedUsers.map((user) => _canonicalUserKey(user.id)).toSet();
    final currentKey = _canonicalUserKey(currentUserId);
    return allRoomUsers
        .where((user) {
          final userKey = _canonicalUserKey(user.id);
          return userKey != currentKey && !seatedKeys.contains(userKey);
        })
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
        avatarColors: const [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
        avatarUrl: entry.senderAvatarUrl,
      );
    }

    final senderKey = _canonicalUserKey(senderId);
    return allRoomUsers.firstWhere(
      (item) => _canonicalUserKey(item.id) == senderKey,
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
        avatarColors: const [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
        avatarUrl: entry.senderAvatarUrl,
      ),
    );
  }

  SeatUser _seatUserFromPeer({
    required LiveMediaPeerSnapshot peer,
    SeatUser? baseUser,
  }) {
    final displayName = peer.displayName.trim().isNotEmpty
        ? peer.displayName.trim()
        : (baseUser?.name ?? _fallbackDisplayNameForUserId(peer.userId));
    return SeatUser(
      id: peer.userId,
      name: displayName,
      roleLabel: peer.isHost
          ? 'Channel Host'
          : peer.isRoomAdmin
          ? 'Admin'
          : (peer.roleLabel.trim().isNotEmpty
                ? peer.roleLabel
                : baseUser?.roleLabel ?? 'Member'),
      familyName: baseUser?.familyName ?? '',
      familyLevel: baseUser?.familyLevel ?? 'bronze',
      relationshipText: baseUser?.relationshipText ?? '',
      vipLevel: peer.vipLevel > 0 ? peer.vipLevel : baseUser?.vipLevel ?? 0,
      svipLevel: peer.svipLevel > 0 ? peer.svipLevel : baseUser?.svipLevel ?? 0,
      sendingLevel: peer.sendingLevel > 0
          ? peer.sendingLevel
          : baseUser?.sendingLevel ?? 0,
      receivingLevel: peer.receivingLevel > 0
          ? peer.receivingLevel
          : baseUser?.receivingLevel ?? 0,
      sentExp: baseUser?.sentExp ?? 0,
      receivedExp: baseUser?.receivedExp ?? 0,
      medals: baseUser?.medals ?? const [],
      avatarColors:
          baseUser?.avatarColors ??
          const [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
      avatarUrl: peer.avatarUrl ?? baseUser?.avatarUrl,
      age: baseUser?.age,
      locationLabel: baseUser?.locationLabel,
      locationVisible: baseUser?.locationVisible ?? true,
      gender: baseUser?.gender ?? RoomUserGender.undisclosed,
      isCurrentUser: baseUser?.isCurrentUser ?? false,
      isHost: peer.isHost || (baseUser?.isHost ?? false),
      isRoomAdmin:
          peer.isRoomAdmin || peer.isHost || (baseUser?.isRoomAdmin ?? false),
      selfMuted: !peer.micEnabled,
      adminMuted: peer.adminMuted,
    );
  }

  SeatUser _mergeSeatWithPresence({
    required SeatUser seatUser,
    SeatUser? presenceUser,
  }) {
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
      avatarUrl: presenceUser.avatarUrl,
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

  SeatUser _mergeDuplicateUser(SeatUser existing, SeatUser incoming) {
    final preferIncomingName = incoming.name.trim().isNotEmpty &&
        !incoming.name.trim().toLowerCase().startsWith('user ');
    return SeatUser(
      id: existing.id,
      name: preferIncomingName ? incoming.name : existing.name,
      roleLabel: incoming.isHost || incoming.isRoomAdmin ? incoming.roleLabel : existing.roleLabel,
      familyName: incoming.familyName.trim().isNotEmpty ? incoming.familyName : existing.familyName,
      familyLevel: incoming.familyLevel,
      relationshipText: incoming.relationshipText.trim().isNotEmpty ? incoming.relationshipText : existing.relationshipText,
      vipLevel: incoming.vipLevel > 0 ? incoming.vipLevel : existing.vipLevel,
      svipLevel: incoming.svipLevel > 0 ? incoming.svipLevel : existing.svipLevel,
      sendingLevel: incoming.sendingLevel > 0 ? incoming.sendingLevel : existing.sendingLevel,
      receivingLevel: incoming.receivingLevel > 0 ? incoming.receivingLevel : existing.receivingLevel,
      sentExp: incoming.sentExp > 0 ? incoming.sentExp : existing.sentExp,
      receivedExp: incoming.receivedExp > 0 ? incoming.receivedExp : existing.receivedExp,
      medals: incoming.medals.isNotEmpty ? incoming.medals : existing.medals,
      avatarColors: incoming.avatarColors.isNotEmpty ? incoming.avatarColors : existing.avatarColors,
      nameGradientColors: incoming.nameGradientColors.isNotEmpty ? incoming.nameGradientColors : existing.nameGradientColors,
      avatarUrl: incoming.avatarUrl ?? existing.avatarUrl,
      equippedAvatarFrameAssetPath: incoming.equippedAvatarFrameAssetPath ?? existing.equippedAvatarFrameAssetPath,
      equippedAvatarFrameImageUrl: incoming.equippedAvatarFrameImageUrl ?? existing.equippedAvatarFrameImageUrl,
      equippedChatBubbleAssetPath: incoming.equippedChatBubbleAssetPath ?? existing.equippedChatBubbleAssetPath,
      equippedChatBubbleImageUrl: incoming.equippedChatBubbleImageUrl ?? existing.equippedChatBubbleImageUrl,
      age: incoming.age ?? existing.age,
      locationLabel: incoming.locationLabel ?? existing.locationLabel,
      locationVisible: incoming.locationVisible || existing.locationVisible,
      gender: incoming.gender != RoomUserGender.undisclosed ? incoming.gender : existing.gender,
      isCurrentUser: existing.isCurrentUser || incoming.isCurrentUser,
      isHost: existing.isHost || incoming.isHost,
      isRoomAdmin: existing.isRoomAdmin || incoming.isRoomAdmin,
      selfMuted: incoming.selfMuted,
      adminMuted: existing.adminMuted || incoming.adminMuted,
      isSpeaking: existing.isSpeaking || incoming.isSpeaking,
    );
  }

  String _canonicalUserKey(String userId) {
    var value = userId.trim();
    if (value.isEmpty) return '';
    value = value.replaceFirst(RegExp(r'^VM\d+_user_'), 'user_');
    value = value.replaceFirst(RegExp(r'^room_\w+_user_'), 'user_');
    if (value.startsWith('user_')) {
      value = value.substring(5);
    }
    if (RegExp(r'^\d+$').hasMatch(value)) {
      return 'u:$value';
    }
    return value.toLowerCase();
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