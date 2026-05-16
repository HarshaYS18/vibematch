import 'package:flutter/material.dart';

enum RoomPrivacyMode { open, locked, membersOnly, privateVibe }

enum GiftCategory {
  classic,
  lucky,
  relationship,
  event,
  premium,
  svip,
  vip,
  baggage,
}

enum RoomUserGender { male, female, undisclosed }

enum RoomSystemEventType { none, userEntered, userRemoved }

extension RoomPrivacyModeX on RoomPrivacyMode {
  String get label {
    switch (this) {
      case RoomPrivacyMode.open:
        return 'Open';
      case RoomPrivacyMode.locked:
        return 'Locked';
      case RoomPrivacyMode.membersOnly:
        return 'Member only';
      case RoomPrivacyMode.privateVibe:
        return 'Private vibe';
    }
  }

  IconData get icon {
    switch (this) {
      case RoomPrivacyMode.open:
        return Icons.public_rounded;
      case RoomPrivacyMode.locked:
        return Icons.lock_rounded;
      case RoomPrivacyMode.membersOnly:
        return Icons.verified_user_rounded;
      case RoomPrivacyMode.privateVibe:
        return Icons.visibility_off_rounded;
    }
  }

  String get shortLabel {
    switch (this) {
      case RoomPrivacyMode.open:
        return 'Open';
      case RoomPrivacyMode.locked:
        return 'Lock';
      case RoomPrivacyMode.membersOnly:
        return 'Member';
      case RoomPrivacyMode.privateVibe:
        return 'Secret';
    }
  }
}

extension GiftCategoryX on GiftCategory {
  String get label {
    switch (this) {
      case GiftCategory.classic:
        return 'Classic';
      case GiftCategory.lucky:
        return 'Lucky';
      case GiftCategory.relationship:
        return 'Relationship';
      case GiftCategory.event:
        return 'Event';
      case GiftCategory.premium:
        return 'Premium';
      case GiftCategory.svip:
        return 'SVIP';
      case GiftCategory.vip:
        return 'VIP';
      case GiftCategory.baggage:
        return 'Baggage';
    }
  }
}

extension RoomUserGenderX on RoomUserGender {
  IconData get icon {
    switch (this) {
      case RoomUserGender.male:
        return Icons.male_rounded;
      case RoomUserGender.female:
        return Icons.female_rounded;
      case RoomUserGender.undisclosed:
        return Icons.person_rounded;
    }
  }

  Color get color {
    switch (this) {
      case RoomUserGender.male:
        return const Color(0xFF4A9BFF);
      case RoomUserGender.female:
        return const Color(0xFFE84C72);
      case RoomUserGender.undisclosed:
        return const Color(0xFF8C8198);
    }
  }
}

class SeatUser {
  const SeatUser({
    required this.id,
    required this.name,
    required this.roleLabel,
    required this.familyName,
    this.familyLevel = 'bronze',
    required this.relationshipText,
    required this.vipLevel,
    required this.sendingLevel,
    required this.receivingLevel,
    required this.sentExp,
    required this.receivedExp,
    required this.medals,
    required this.avatarColors,
    this.avatarUrl,
    this.equippedAvatarFrameAssetPath,
    this.equippedAvatarFrameImageUrl,
    this.equippedChatBubbleAssetPath,
    this.equippedChatBubbleImageUrl,
    this.svipLevel = 0,
    this.age,
    this.locationLabel,
    this.locationVisible = true,
    this.gender = RoomUserGender.undisclosed,
    this.isCurrentUser = false,
    this.isHost = false,
    this.isRoomAdmin = false,
    this.selfMuted = false,
    this.adminMuted = false,
  });

  final String id;
  final String name;
  final String roleLabel;
  final String familyName;
  final String familyLevel;
  final String relationshipText;
  final int vipLevel;
  final int sendingLevel;
  final int receivingLevel;
  final int sentExp;
  final int receivedExp;
  final List<String> medals;
  final List<Color> avatarColors;
  final String? avatarUrl;
  final String? equippedAvatarFrameAssetPath;
  final String? equippedAvatarFrameImageUrl;
  final String? equippedChatBubbleAssetPath;
  final String? equippedChatBubbleImageUrl;
  final int svipLevel;
  final int? age;
  final String? locationLabel;
  final bool locationVisible;
  final RoomUserGender gender;
  final bool isCurrentUser;
  final bool isHost;
  final bool isRoomAdmin;
  final bool selfMuted;
  final bool adminMuted;

  bool get muted => selfMuted || adminMuted;
  bool get showLocation => locationVisible && (locationLabel?.trim().isNotEmpty ?? false);

  SeatUser copyWith({
    String? name,
    String? roleLabel,
    String? familyName,
    String? familyLevel,
    String? relationshipText,
    int? vipLevel,
    int? sendingLevel,
    int? receivingLevel,
    int? sentExp,
    int? receivedExp,
    List<String>? medals,
    List<Color>? avatarColors,
    String? avatarUrl,
    String? equippedAvatarFrameAssetPath,
    String? equippedAvatarFrameImageUrl,
    String? equippedChatBubbleAssetPath,
    String? equippedChatBubbleImageUrl,
    bool clearAvatarUrl = false,
    bool? isCurrentUser,
    bool? isHost,
    bool? isRoomAdmin,
    bool? selfMuted,
    bool? adminMuted,
    RoomUserGender? gender,
    int? svipLevel,
    int? age,
    String? locationLabel,
    bool? locationVisible,
  }) {
    return SeatUser(
      id: id,
      name: name ?? this.name,
      roleLabel: roleLabel ?? this.roleLabel,
      familyName: familyName ?? this.familyName,
      familyLevel: familyLevel ?? this.familyLevel,
      relationshipText: relationshipText ?? this.relationshipText,
      vipLevel: vipLevel ?? this.vipLevel,
      sendingLevel: sendingLevel ?? this.sendingLevel,
      receivingLevel: receivingLevel ?? this.receivingLevel,
      sentExp: sentExp ?? this.sentExp,
      receivedExp: receivedExp ?? this.receivedExp,
      medals: medals ?? this.medals,
      avatarColors: avatarColors ?? this.avatarColors,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      equippedAvatarFrameAssetPath: equippedAvatarFrameAssetPath ?? this.equippedAvatarFrameAssetPath,
      equippedAvatarFrameImageUrl: equippedAvatarFrameImageUrl ?? this.equippedAvatarFrameImageUrl,
      equippedChatBubbleAssetPath: equippedChatBubbleAssetPath ?? this.equippedChatBubbleAssetPath,
      equippedChatBubbleImageUrl: equippedChatBubbleImageUrl ?? this.equippedChatBubbleImageUrl,
      svipLevel: svipLevel ?? this.svipLevel,
      age: age ?? this.age,
      locationLabel: locationLabel ?? this.locationLabel,
      locationVisible: locationVisible ?? this.locationVisible,
      gender: gender ?? this.gender,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      isHost: isHost ?? this.isHost,
      isRoomAdmin: isRoomAdmin ?? this.isRoomAdmin,
      selfMuted: selfMuted ?? this.selfMuted,
      adminMuted: adminMuted ?? this.adminMuted,
    );
  }
}

class RoomSeat {
  const RoomSeat({required this.index, this.user, this.locked = false});
  final int index;
  final SeatUser? user;
  final bool locked;
  RoomSeat copyWith({SeatUser? user, bool clearUser = false, bool? locked}) => RoomSeat(index: index, user: clearUser ? null : (user ?? this.user), locked: locked ?? this.locked);
}

class ChatEntry {
  ChatEntry({
    required this.senderName,
    required this.message,
    this.senderId,
    this.senderAvatarUrl,
    this.vipLevel = 0,
    this.sendingLevel = 0,
    this.receivingLevel = 0,
    this.isGift = false,
    this.isSeatApplication = false,
    this.seatIndex,
    this.applicationCreatedAt,
    this.applicationExpiresAt,
    this.applicationApproved = false,
    this.applicationRejected = false,
    this.applicationExpired = false,
    this.systemEventType = RoomSystemEventType.none,
    this.autoDismissAt,
    this.giftAssetPath,
    this.imageUrl,
    this.imageContentType,
  });
  final String senderName;
  final String message;
  final String? senderId;
  final String? senderAvatarUrl;
  final int vipLevel;
  final int sendingLevel;
  final int receivingLevel;
  final bool isGift;
  final bool isSeatApplication;
  final int? seatIndex;
  final DateTime? applicationCreatedAt;
  final DateTime? applicationExpiresAt;
  final bool applicationApproved;
  final bool applicationRejected;
  final bool applicationExpired;
  final RoomSystemEventType systemEventType;
  final DateTime? autoDismissAt;
  final String? giftAssetPath;
  final String? imageUrl;
  final String? imageContentType;
}

String avatarLetter(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return '?';
  return clean.characters.first.toUpperCase();
}
