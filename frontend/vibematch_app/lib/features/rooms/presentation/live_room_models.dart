import 'package:flutter/material.dart';

enum RoomPrivacyMode { open, locked, membersOnly, privateVibe }

enum GiftCategory { classic, lucky, event, svip, premium, baggage }

enum RoomUserGender { male, female, undisclosed }

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
      case GiftCategory.event:
        return 'Event';
      case GiftCategory.svip:
        return 'SVIP';
      case GiftCategory.premium:
        return 'Premium';
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
    required this.relationshipText,
    required this.vipLevel,
    required this.sendingLevel,
    required this.receivingLevel,
    required this.sentExp,
    required this.receivedExp,
    required this.medals,
    required this.avatarColors,
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
  final String relationshipText;
  final int vipLevel;
  final int sendingLevel;
  final int receivingLevel;
  final int sentExp;
  final int receivedExp;
  final List<String> medals;
  final List<Color> avatarColors;
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
    String? roleLabel,
    int? sentExp,
    int? receivedExp,
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
      name: name,
      roleLabel: roleLabel ?? this.roleLabel,
      familyName: familyName,
      relationshipText: relationshipText,
      vipLevel: vipLevel,
      sendingLevel: sendingLevel,
      receivingLevel: receivingLevel,
      sentExp: sentExp ?? this.sentExp,
      receivedExp: receivedExp ?? this.receivedExp,
      medals: medals,
      avatarColors: avatarColors,
      svipLevel: svipLevel ?? this.svipLevel,
      age: age ?? this.age,
      locationLabel: locationLabel ?? this.locationLabel,
      locationVisible: locationVisible ?? this.locationVisible,
      gender: gender ?? this.gender,
      isCurrentUser: isCurrentUser,
      isHost: isHost,
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

  RoomSeat copyWith({SeatUser? user, bool clearUser = false, bool? locked}) {
    return RoomSeat(
      index: index,
      user: clearUser ? null : (user ?? this.user),
      locked: locked ?? this.locked,
    );
  }
}

class ChatEntry {
  const ChatEntry({
    required this.senderName,
    required this.message,
    this.senderId,
    this.vipLevel = 0,
    this.sendingLevel = 0,
    this.receivingLevel = 0,
    this.isGift = false,
    this.isSeatApplication = false,
    this.seatIndex,
    this.applicationApproved = false,
    this.giftAssetPath,
  });

  final String senderName;
  final String message;
  final String? senderId;
  final int vipLevel;
  final int sendingLevel;
  final int receivingLevel;
  final bool isGift;
  final bool isSeatApplication;
  final int? seatIndex;
  final bool applicationApproved;
  final String? giftAssetPath;

  ChatEntry copyWith({String? message, bool? applicationApproved}) {
    return ChatEntry(
      senderName: senderName,
      message: message ?? this.message,
      senderId: senderId,
      vipLevel: vipLevel,
      sendingLevel: sendingLevel,
      receivingLevel: receivingLevel,
      isGift: isGift,
      isSeatApplication: isSeatApplication,
      seatIndex: seatIndex,
      applicationApproved: applicationApproved ?? this.applicationApproved,
      giftAssetPath: giftAssetPath,
    );
  }
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

  GiftSlide copyWith({int? combo, int? baseCombo, int? remainingSeconds}) {
    return GiftSlide(
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
}

class SeatLayoutSpec {
  const SeatLayoutSpec({required this.id, required this.columns, required this.rows, required this.hasHostSeats});
  final String id;
  final int columns;
  final int rows;
  final bool hasHostSeats;
  int get topSeatCount => hasHostSeats ? 2 : 0;
  int get totalSeats => topSeatCount + (columns * rows);
  String get label => hasHostSeats ? 'Host + ${columns}x$rows' : '${columns}x$rows';
  static const List<String> withoutHostLayouts = ['4x2', '5x2', '4x3', '5x3'];
  static const List<String> withHostLayouts = ['host_4x2', 'host_5x2', 'host_4x3', 'host_5x3'];
  static SeatLayoutSpec parse(String id) {
    final hasHost = id.startsWith('host_');
    final raw = id.replaceFirst('host_', '');
    final parts = raw.split('x');
    final columns = int.tryParse(parts.first) ?? 4;
    final rows = int.tryParse(parts.length > 1 ? parts.last : '2') ?? 2;
    return SeatLayoutSpec(id: id, columns: columns, rows: rows, hasHostSeats: hasHost);
  }
}

String avatarLetter(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.substring(0, 1).toUpperCase();
}

String compactNumber(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  return '$value';
}

RoomPrivacyMode privacyModeFromTitle(String title) {
  final value = title.toLowerCase();
  if (value.contains('lock')) return RoomPrivacyMode.locked;
  if (value.contains('member')) return RoomPrivacyMode.membersOnly;
  if (value.contains('private') || value.contains('secret')) return RoomPrivacyMode.privateVibe;
  return RoomPrivacyMode.open;
}

const List<SeatUser> mockRoomUsers = [
  SeatUser(id: 'founder_owner', name: 'Harsha', roleLabel: 'Channel Host', familyName: 'Moon Fam', relationshipText: 'Love: Riya • Bonds: Arjun, Kiran', vipLevel: 32, svipLevel: 3, sendingLevel: 52, receivingLevel: 44, sentExp: 98200, receivedExp: 124500, medals: ['🏆', '💎', '🔥'], avatarColors: [Color(0xFFFFC857), Color(0xFFFF5F7E)], gender: RoomUserGender.male, age: 27, locationLabel: 'Vijayawada, India', isCurrentUser: true, isHost: true, isRoomAdmin: true),
  SeatUser(id: 'riya', name: 'Riya', roleLabel: 'Administrator', familyName: 'Moon Fam', relationshipText: 'Love: Harsha • Bonds: Meera', vipLevel: 28, svipLevel: 1, sendingLevel: 41, receivingLevel: 38, sentExp: 65400, receivedExp: 90500, medals: ['🌙', '🎖️'], avatarColors: [Color(0xFF18C7B7), Color(0xFF5E6DFF)], gender: RoomUserGender.female, age: 24, locationLabel: 'Hyderabad, India', isRoomAdmin: true),
  SeatUser(id: 'arjun', name: 'Arjun', roleLabel: 'Member', familyName: 'Moon Fam', relationshipText: 'Bond: Harsha', vipLevel: 18, svipLevel: 0, sendingLevel: 22, receivingLevel: 17, sentExp: 22500, receivedExp: 34100, medals: ['⭐'], avatarColors: [Color(0xFFE84C72), Color(0xFFB13C77)], gender: RoomUserGender.male, age: 25, locationLabel: 'Bengaluru, India'),
];

const List<SeatUser> mockInviteUsers = [
  SeatUser(id: 'meera', name: 'Meera', roleLabel: 'Member', familyName: 'Star House', relationshipText: 'Bond: Riya', vipLevel: 9, svipLevel: 0, sendingLevel: 14, receivingLevel: 11, sentExp: 8800, receivedExp: 12300, medals: ['🌟'], avatarColors: [Color(0xFF7A5CFF), Color(0xFF12C7B7)], gender: RoomUserGender.female, age: 23, locationLabel: 'Chennai, India'),
  SeatUser(id: 'nikhil', name: 'Nikhil', roleLabel: 'Guest', familyName: '', relationshipText: '', vipLevel: 4, svipLevel: 0, sendingLevel: 7, receivingLevel: 5, sentExp: 2100, receivedExp: 1700, medals: [], avatarColors: [Color(0xFFFF7A45), Color(0xFFE84C72)], gender: RoomUserGender.male, age: 22, locationLabel: 'Nandyal, India'),
  SeatUser(id: 'kiran', name: 'Kiran', roleLabel: 'Member', familyName: 'Moon Fam', relationshipText: 'Bond: Harsha', vipLevel: 13, svipLevel: 0, sendingLevel: 20, receivingLevel: 16, sentExp: 14800, receivedExp: 11600, medals: ['🔥'], avatarColors: [Color(0xFFFFC857), Color(0xFF7A5CFF)], gender: RoomUserGender.male, age: 26, locationLabel: 'Vizag, India', locationVisible: false),
];

const List<ChatEntry> mockChatEntries = [];

const List<GiftItem> mockGiftItems = [
  GiftItem(id: 'love_bomb', name: 'Love Bomb', category: GiftCategory.classic, coins: 1, icon: Icons.favorite_rounded, chatSymbol: '❤️', assetPath: 'assets/images/gifts/love_bomb.png', colors: [Color(0xFFFF5F7E), Color(0xFFFFC857)]),
  GiftItem(id: 'love_rocket', name: 'Love Rocket', category: GiftCategory.premium, coins: 999, icon: Icons.rocket_launch_rounded, chatSymbol: '🚀', assetPath: 'assets/gifts/love_rocket/icon/love_rocket_icon.webp', videoAssetPath: 'assets/gifts/love_rocket/effect/love_rocket_effect.webp', colors: [Color(0xFFFF5F7E), Color(0xFFFFC857)]),
  GiftItem(id: 'rocket', name: 'Rocket', category: GiftCategory.classic, coins: 99, icon: Icons.rocket_launch_rounded, chatSymbol: '🚀', assetPath: 'assets/images/gifts/rocket.png', colors: [Color(0xFF18C7B7), Color(0xFF6C63FF)]),
  GiftItem(id: 'lucky_star', name: 'Lucky Star', category: GiftCategory.lucky, coins: 19, icon: Icons.auto_awesome_rounded, chatSymbol: '✨', assetPath: 'assets/images/gifts/lucky_star.png', colors: [Color(0xFFFFD166), Color(0xFFFF7A45)]),
  GiftItem(id: 'event_crown', name: 'Event Crown', category: GiftCategory.event, coins: 199, icon: Icons.emoji_events_rounded, chatSymbol: '🏆', assetPath: 'assets/images/gifts/event_crown.png', colors: [Color(0xFFC99A3B), Color(0xFFE84C72)]),
  GiftItem(id: 'svip_aura', name: 'SVIP Aura', category: GiftCategory.svip, coins: 399, icon: Icons.diamond_rounded, chatSymbol: '💎', assetPath: 'assets/images/gifts/svip_aura.png', colors: [Color(0xFF8C5CF6), Color(0xFF12C7B7)]),
  GiftItem(id: 'royal_crown', name: 'Royal Crown', category: GiftCategory.premium, coins: 999, icon: Icons.workspace_premium_rounded, chatSymbol: '👑', assetPath: 'assets/images/gifts/royal_crown.png', colors: [Color(0xFFFFD166), Color(0xFF111827)]),
  GiftItem(id: 'owned_rose_pack', name: 'Rose Pack', category: GiftCategory.baggage, coins: 0, icon: Icons.inventory_2_rounded, chatSymbol: '🎒', assetPath: 'assets/images/gifts/rose_pack.png', colors: [Color(0xFFFF6B9A), Color(0xFFFFC2D8)]),
  GiftItem(id: 'owned_lucky_box', name: 'Lucky Box', category: GiftCategory.baggage, coins: 0, icon: Icons.card_giftcard_rounded, chatSymbol: '🎁', assetPath: 'assets/images/gifts/lucky_box.png', colors: [Color(0xFFFFD166), Color(0xFFFF7A45)]),
];
