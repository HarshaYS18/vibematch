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
    this.nameGradientColors = const <String>[],
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
    this.isSpeaking = false,
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
  final List<String> nameGradientColors;
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
  final bool isSpeaking;

  bool get muted => selfMuted || adminMuted;
  bool get showLocation =>
      locationVisible && (locationLabel?.trim().isNotEmpty ?? false);

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
    List<String>? nameGradientColors,
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
    bool? isSpeaking,
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
      nameGradientColors: nameGradientColors ?? this.nameGradientColors,
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
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }
}

class RoomSeat {
  const RoomSeat({required this.index, this.user, this.locked = false});
  final int index;
  final SeatUser? user;
  final bool locked;
  RoomSeat copyWith({SeatUser? user, bool clearUser = false, bool? locked}) =>
      RoomSeat(
        index: index,
        user: clearUser ? null : (user ?? this.user),
        locked: locked ?? this.locked,
      );
}

class ChatEntry {
  ChatEntry({
    required this.senderName,
    required this.message,
    this.senderId,
    this.senderAvatarUrl,
    this.senderNameGradientColors = const <String>[],
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
  final List<String> senderNameGradientColors;
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
  bool get isSystemMessage =>
      senderId == 'system' || systemEventType != RoomSystemEventType.none;
  bool get shouldAutoDismiss => autoDismissAt != null;
  bool get autoDismissed =>
      autoDismissAt != null && DateTime.now().isAfter(autoDismissAt!);
  bool get applicationTimedOut =>
      applicationExpired ||
      (applicationExpiresAt != null &&
          DateTime.now().isAfter(applicationExpiresAt!));
  bool get applicationResolved =>
      applicationApproved || applicationRejected || applicationTimedOut;
  bool get isImageMessage => imageUrl?.trim().isNotEmpty ?? false;
  ChatEntry copyWith({
    String? message,
    String? senderAvatarUrl,
    List<String>? senderNameGradientColors,
    bool clearSenderAvatarUrl = false,
    bool? applicationApproved,
    bool? applicationRejected,
    bool? applicationExpired,
    RoomSystemEventType? systemEventType,
    DateTime? autoDismissAt,
    String? imageUrl,
    String? imageContentType,
  }) => ChatEntry(
    senderName: senderName,
    message: message ?? this.message,
    senderId: senderId,
    senderAvatarUrl: clearSenderAvatarUrl
        ? null
        : senderAvatarUrl ?? this.senderAvatarUrl,
    senderNameGradientColors: senderNameGradientColors ?? this.senderNameGradientColors,
    vipLevel: vipLevel,
    sendingLevel: sendingLevel,
    receivingLevel: receivingLevel,
    isGift: isGift,
    isSeatApplication: isSeatApplication,
    seatIndex: seatIndex,
    applicationCreatedAt: applicationCreatedAt,
    applicationExpiresAt: applicationExpiresAt,
    applicationApproved: applicationApproved ?? this.applicationApproved,
    applicationRejected: applicationRejected ?? this.applicationRejected,
    applicationExpired: applicationExpired ?? this.applicationExpired,
    systemEventType: systemEventType ?? this.systemEventType,
    autoDismissAt: autoDismissAt ?? this.autoDismissAt,
    giftAssetPath: giftAssetPath,
    imageUrl: imageUrl ?? this.imageUrl,
    imageContentType: imageContentType ?? this.imageContentType,
  );
}

class GiftItem {
  const GiftItem({
    required this.id,
    required this.name,
    required this.category,
    required this.coins,
    required this.icon,
    required this.chatSymbol,
    required this.colors,
    this.assetPath,
    this.videoAssetPath,
  });
  final String id;
  final String name;
  final GiftCategory category;
  final int coins;
  final IconData icon;
  final String chatSymbol;
  final List<Color> colors;
  final String? assetPath;
  final String? videoAssetPath;
  bool get isVideoGift => videoAssetPath?.trim().isNotEmpty ?? false;
}

class GiftSlide {
  const GiftSlide({
    required this.id,
    required this.senderName,
    required this.receiverName,
    required this.giftName,
    required this.giftIcon,
    this.giftAssetPath,
    this.videoAssetPath,
    required this.colors,
    required this.combo,
    this.baseCombo = 1,
    required this.remainingSeconds,
  });
  final String id;
  final String senderName;
  final String receiverName;
  final String giftName;
  final IconData giftIcon;
  final String? giftAssetPath;
  final String? videoAssetPath;
  final List<Color> colors;
  final int combo;
  final int baseCombo;
  final int remainingSeconds;
  bool get isVideoGift => videoAssetPath?.trim().isNotEmpty ?? false;
  GiftSlide copyWith({int? combo, int? baseCombo, int? remainingSeconds}) =>
      GiftSlide(
        id: id,
        senderName: senderName,
        receiverName: receiverName,
        giftName: giftName,
        giftIcon: giftIcon,
        giftAssetPath: giftAssetPath,
        videoAssetPath: videoAssetPath,
        colors: colors,
        combo: combo ?? this.combo,
        baseCombo: baseCombo ?? this.baseCombo,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      );
}

class SeatLayoutSpec {
  const SeatLayoutSpec({
    required this.id,
    required this.columns,
    required this.rows,
    required this.hasHostSeats,
  });
  final String id;
  final int columns;
  final int rows;
  final bool hasHostSeats;
  int get topSeatCount => hasHostSeats ? 2 : 0;
  int get totalSeats => topSeatCount + (columns * rows);
  String get label =>
      hasHostSeats ? 'Host + ${columns}x$rows' : '${columns}x$rows';
  static const List<String> withoutHostLayouts = ['4x2', '5x2', '4x3', '5x3'];
  static const List<String> withHostLayouts = [
    'host_4x2',
    'host_5x2',
    'host_4x3',
    'host_5x3',
  ];
  static SeatLayoutSpec parse(String id) {
    final hasHost = id.startsWith('host_');
    final raw = id.replaceFirst('host_', '');
    final parts = raw.split('x');
    final columns = int.tryParse(parts.first) ?? 4;
    final rows = int.tryParse(parts.length > 1 ? parts.last : '2') ?? 2;
    return SeatLayoutSpec(
      id: id,
      columns: columns,
      rows: rows,
      hasHostSeats: hasHost,
    );
  }
}

String avatarLetter(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  return trimmed.substring(0, 1).toUpperCase();
}

String compactNumber(int value) {
  if (value >= 1000000000) {
    return '${_trimCompactDecimal(value / 1000000000)}B';
  }
  if (value >= 1000000) {
    return '${_trimCompactDecimal(value / 1000000)}M';
  }
  if (value >= 1000) {
    return '${_trimCompactDecimal(value / 1000)}K';
  }
  return '$value';
}

String _trimCompactDecimal(double value) {
  final decimals = value >= 100 ? 0 : value >= 10 ? 1 : 2;
  final fixed = value.toStringAsFixed(decimals);
  return fixed.replaceFirst(RegExp(r'\.0+$'), '').replaceFirst(RegExp(r'(\.\d*[1-9])0+$'), r'$1');
}

RoomPrivacyMode privacyModeFromTitle(String title) {
  final value = title.toLowerCase();
  if (value.contains('lock')) {
    return RoomPrivacyMode.locked;
  }
  if (value.contains('member')) {
    return RoomPrivacyMode.membersOnly;
  }
  if (value.contains('private') || value.contains('secret')) {
    return RoomPrivacyMode.privateVibe;
  }
  return RoomPrivacyMode.open;
}

final List<SeatUser> mockRoomUsers = <SeatUser>[];
final List<SeatUser> mockInviteUsers = <SeatUser>[];
final List<ChatEntry> mockChatEntries = <ChatEntry>[];

const List<GiftItem> mockGiftItems = [
  GiftItem(
    id: 'rose_bloom',
    name: 'Rose Bloom',
    category: GiftCategory.classic,
    coins: 9,
    icon: Icons.favorite_rounded,
    chatSymbol: '🌹',
    assetPath: 'assets/gifts/normal/rose_bloom.webp',
    colors: [Color(0xFFFF5F7E), Color(0xFFFFB3C1)],
  ),
  GiftItem(
    id: 'gold_coin',
    name: 'Gold Coin',
    category: GiftCategory.classic,
    coins: 29,
    icon: Icons.paid_rounded,
    chatSymbol: '🪙',
    assetPath: 'assets/gifts/normal/gold_coin.webp',
    colors: [Color(0xFFFFC857), Color(0xFFC99A3B)],
  ),
  GiftItem(
    id: 'party_pop',
    name: 'Party Pop',
    category: GiftCategory.classic,
    coins: 99,
    icon: Icons.celebration_rounded,
    chatSymbol: '🎉',
    assetPath: 'assets/gifts/normal/party_pop.webp',
    colors: [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
  ),
  GiftItem(
    id: 'love_rocket',
    name: 'Love Rocket',
    category: GiftCategory.premium,
    coins: 999,
    icon: Icons.rocket_launch_rounded,
    chatSymbol: '🚀',
    assetPath: 'assets/gifts/love_rocket/icon/love_rocket_icon.webp',
    videoAssetPath: 'assets/videos/gifts/love_rocket.mp4',
    colors: [Color(0xFFFF5F7E), Color(0xFFFFC857)],
  ),
  GiftItem(
    id: 'arcane_crystal_wand',
    name: 'Arcane Crystal Wand',
    category: GiftCategory.lucky,
    coins: 99,
    icon: Icons.auto_fix_high_rounded,
    chatSymbol: '🪄',
    assetPath: 'assets/gifts/lucky/arcane_crystal_wand.png',
    colors: [Color(0xFF8C5CF6), Color(0xFFC99A3B)],
  ),
  GiftItem(
    id: 'celestial_rose',
    name: 'Celestial Rose',
    category: GiftCategory.lucky,
    coins: 199,
    icon: Icons.favorite_border_rounded,
    chatSymbol: '🌹',
    assetPath: 'assets/gifts/lucky/celestial_rose.png',
    colors: [Color(0xFFE84C72), Color(0xFFFFD166)],
  ),
  GiftItem(
    id: 'eternal_bond_rings',
    name: 'Eternal Bond Rings',
    category: GiftCategory.lucky,
    coins: 299,
    icon: Icons.diamond_rounded,
    chatSymbol: '💍',
    assetPath: 'assets/gifts/lucky/eternal_bond_rings.png',
    colors: [Color(0xFFC99A3B), Color(0xFFEDE3D7)],
  ),
  GiftItem(
    id: 'bubble_elephant',
    name: 'Bubble Elephant',
    category: GiftCategory.lucky,
    coins: 99,
    icon: Icons.pets_rounded,
    chatSymbol: '🐘',
    assetPath: 'assets/gifts/lucky/bubble_elephant.png',
    colors: [Color(0xFFFF9CCB), Color(0xFFEDE3D7)],
  ),
  GiftItem(
    id: 'sun_fortune_coin',
    name: 'Sun Fortune Coin',
    category: GiftCategory.lucky,
    coins: 499,
    icon: Icons.wb_sunny_rounded,
    chatSymbol: '☀️',
    assetPath: 'assets/gifts/lucky/sun_fortune_coin.png',
    colors: [Color(0xFFFFC857), Color(0xFFC99A3B)],
  ),
  GiftItem(
    id: 'moonlit_koi',
    name: 'Moonlit Koi',
    category: GiftCategory.lucky,
    coins: 299,
    icon: Icons.waves_rounded,
    chatSymbol: '🐟',
    assetPath: 'assets/gifts/lucky/moonlit_koi.png',
    colors: [Color(0xFFEDE3D7), Color(0xFF251538)],
  ),
  GiftItem(
    id: 'spellbound_tome',
    name: 'Spellbound Tome',
    category: GiftCategory.lucky,
    coins: 999,
    icon: Icons.auto_stories_rounded,
    chatSymbol: '📖',
    assetPath: 'assets/gifts/lucky/spellbound_tome.png',
    colors: [Color(0xFF6D5DF6), Color(0xFF12C7B7)],
  ),
];