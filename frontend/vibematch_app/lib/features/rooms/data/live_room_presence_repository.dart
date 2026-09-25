import 'package:flutter/material.dart';

import '../../auth/models/user_identity_snapshot.dart';
import '../presentation/live_room_models.dart';

/// Pure compatibility mapper for canonical room snapshots.
///
/// Chunk 33 removed the legacy static participant cache and old room
/// join/heartbeat network facade. RoomSessionRepository owns mutable client
/// room state; this type only converts backend/canonical JSON into legacy
/// presentation models while those widgets are being retired.
class LiveRoomPresenceSnapshot {
  const LiveRoomPresenceSnapshot({
    required this.roomId,
    required this.onlineCount,
    required this.participants,
    this.roomMemberByUserId = const <String, bool>{},
    this.joinedUser,
    this.shouldShowEnteredMessage = false,
  });

  final String roomId;
  final int onlineCount;
  final List<SeatUser> participants;
  final Map<String, bool> roomMemberByUserId;
  final SeatUser? joinedUser;
  final bool shouldShowEnteredMessage;

  factory LiveRoomPresenceSnapshot.fromJoinJson(Map<String, dynamic> json) {
    final room = json['room'] is Map<String, dynamic>
        ? json['room'] as Map<String, dynamic>
        : <String, dynamic>{};
    final joinedRaw = json['joined_user'];
    return LiveRoomPresenceSnapshot(
      roomId: room['id']?.toString() ?? '',
      onlineCount: _int(room['online_count']),
      participants: onlineParticipants(json['participants']),
      roomMemberByUserId: roomMembershipByUserId(json['participants']),
      joinedUser: joinedRaw is Map<String, dynamic>
          ? participantToSeatUser(joinedRaw)
          : null,
      shouldShowEnteredMessage: json['should_show_entered_message'] == true,
    );
  }

  factory LiveRoomPresenceSnapshot.fromJson(Map<String, dynamic> json) {
    return LiveRoomPresenceSnapshot(
      roomId: json['room_id']?.toString() ?? '',
      onlineCount: _int(json['online_count']),
      participants: _participants(json['participants']),
      roomMemberByUserId: roomMembershipByUserId(json['participants']),
    );
  }

  static Map<String, bool> roomMembershipByUserId(dynamic raw) {
    if (raw is! List) return const <String, bool>{};
    final result = <String, bool>{};
    for (final participant in raw.whereType<Map<String, dynamic>>()) {
      final identity = UserIdentitySnapshot.fromJson(participant);
      if (identity.backendUserId <= 0 && identity.publicUserId <= 0) continue;
      result[identity.roomUserId] = isRoomMemberParticipant(participant);
    }
    return Map<String, bool>.unmodifiable(result);
  }

  static bool isRoomMemberParticipant(Map<String, dynamic> json) {
    return json['is_member'] == true ||
        json['is_room_member'] == true ||
        json['is_room_admin'] == true ||
        json['is_owner'] == true;
  }

  static List<SeatUser> onlineParticipants(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .where((participant) => participant['is_online'] == true)
        .map(participantToSeatUser)
        .toList(growable: false);
  }

  static List<SeatUser> _participants(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(participantToSeatUser)
        .toList(growable: false);
  }

  static SeatUser participantToSeatUser(Map<String, dynamic> json) {
    final identity = UserIdentitySnapshot.fromJson(json);
    final isOwner = json['is_owner'] == true;
    final isRoomAdmin = json['is_room_admin'] == true;
    final isMember = json['is_member'] == true;
    final roleLabel = isOwner
        ? 'Channel Host'
        : isRoomAdmin
        ? 'Admin'
        : isMember
        ? 'Member'
        : identity.roleDisplayLabel;

    final avatarFrame = identity.equippedItems.avatarFrame;
    final chatBubble = identity.equippedItems.chatBubble;

    return SeatUser(
      id: identity.roomUserId,
      name: identity.visibleName,
      roleLabel: roleLabel,
      familyName: '',
      familyLevel: 'bronze',
      relationshipText: '',
      vipLevel: identity.vip.vipLevel,
      svipLevel: identity.vip.svipLevel,
      sendingLevel: identity.sendLevel,
      receivingLevel: identity.receiveLevel,
      sentExp: identity.sentExp,
      receivedExp: identity.receivedExp,
      medals: const [],
      avatarColors: _avatarColors(
        identity.publicUserId > 0
            ? identity.publicUserId.toString()
            : identity.roomUserId,
      ),
      nameGradientColors: identity.vip.nameGradientColors,
      avatarUrl: identity.avatarUrl,
      equippedAvatarFrameAssetPath: avatarFrame?.assetPath,
      equippedAvatarFrameImageUrl: avatarFrame?.bestImageUrl,
      equippedChatBubbleAssetPath: chatBubble?.assetPath,
      equippedChatBubbleImageUrl: chatBubble?.bestImageUrl,
      isHost: isOwner,
      isRoomAdmin: isRoomAdmin || isOwner,
    );
  }
}

List<Color> _avatarColors(String seed) {
  final hash = seed.hashCode.abs();
  final palettes = <List<Color>>[
    const [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
    const [Color(0xFFE84C72), Color(0xFF8C5CF6)],
    const [Color(0xFFFFC857), Color(0xFFE84C72)],
    const [Color(0xFF4A9BFF), Color(0xFF12C7B7)],
  ];
  return palettes[hash % palettes.length];
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
