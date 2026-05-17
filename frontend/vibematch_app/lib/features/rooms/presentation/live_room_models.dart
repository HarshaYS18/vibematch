import 'package:flutter/material.dart';

// NOTE: This file intentionally keeps the existing live-room model surface
// compact. Gift asset CDN fields are render-only metadata; backend remains the
// source of truth for price, ownership, lucky results, category enablement, and
// broadcast eligibility.

enum RoomPrivacyMode {
  open('Open', Icons.public_rounded),
  locked('Locked', Icons.lock_rounded),
  secret('Secret Vibe', Icons.visibility_off_rounded);

  const RoomPrivacyMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum GiftCategory {
  classic('Classic'),
  lucky('Lucky'),
  event('Event'),
  svip('SVIP'),
  premium('Premium'),
  baggage('Baggage');

  const GiftCategory(this.label);
  final String label;
}

enum RoomSystemEventType { userEntered, userRemoved }

class SeatUser {
  const SeatUser({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.vipLevel = 0,
    this.sendingLevel = 0,
    this.receivingLevel = 0,
    this.isHost = false,
    this.isRoomAdmin = false,
    this.roleLabel,
    this.familyName,
    this.publicUserId,
    this.monthlySentCoins = 0,
    this.monthlyReceivedCoins = 0,
    this.isOnline = true,
    this.isMicMuted = false,
    this.isAdminMuted = false,
    this.avatarColors = const <Color>[Color(0xFF12C7B7), Color(0xFF6D5DF6)],
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final int vipLevel;
  final int sendingLevel;
  final int receivingLevel;
  final bool isHost;
  final bool isRoomAdmin;
  final String? roleLabel;
  final String? familyName;
  final int? publicUserId;
  final int monthlySentCoins;
  final int monthlyReceivedCoins;
  final bool isOnline;
  final bool isMicMuted;
  final bool isAdminMuted;
  final List<Color> avatarColors;

  SeatUser copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    int? vipLevel,
    int? sendingLevel,
    int? receivingLevel,
    bool? isHost,
    bool? isRoomAdmin,
    String? roleLabel,
    bool clearRoleLabel = false,
    String? familyName,
    bool clearFamilyName = false,
    int? publicUserId,
    bool clearPublicUserId = false,
    int? monthlySentCoins,
    int? monthlyReceivedCoins,
    bool? isOnline,
    bool? isMicMuted,
    bool? isAdminMuted,
    List<Color>? avatarColors,
  }) {
    return SeatUser(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: clearAvatarUrl ? null : avatarUrl ?? this.avatarUrl,
      vipLevel: vipLevel ?? this.vipLevel,
      sendingLevel: sendingLevel ?? this.sendingLevel,
      receivingLevel: receivingLevel ?? this.receivingLevel,
      isHost: isHost ?? this.isHost,
      isRoomAdmin: isRoomAdmin ?? this.isRoomAdmin,
      roleLabel: clearRoleLabel ? null : roleLabel ?? this.roleLabel,
      familyName: clearFamilyName ? null : familyName ?? this.familyName,
      publicUserId: clearPublicUserId ? null : publicUserId ?? this.publicUserId,
      monthlySentCoins: monthlySentCoins ?? this.monthlySentCoins,
      monthlyReceivedCoins: monthlyReceivedCoins ?? this.monthlyReceivedCoins,
      isOnline: isOnline ?? this.isOnline,
      isMicMuted: isMicMuted ?? this.isMicMuted,
      isAdminMuted: isAdminMuted ?? this.isAdminMuted,
      avatarColors: avatarColors ?? this.avatarColors,
    );
  }
}

class RoomSeat {
  const RoomSeat({
    required this.index,
    this.user,
    this.locked = false,
  });

  final int index;
  final SeatUser? user;
  final bool locked;

  RoomSeat copyWith({SeatUser? user, bool clearUser = false, bool? locked}) {
    return RoomSeat(
      index: index,
      user: clearUser ? null : user ?? this.user,
      locked: locked ?? this.locked,
    );
  }
}

class ChatEntry {
  const ChatEntry({
    required this.senderName,
    required this.message,
    this.senderId,
    this.senderAvatarUrl,
    this.senderNameGradientColors = const <Color>[Color(0xFF12C7B7), Color(0xFF6D5DF6)],
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
    this.systemEventType,
    this.autoDismissAt,
    this.giftAssetPath,
    this.imageUrl,
    this.imageContentType,
  });

  final String senderName;
  final String message;
  final String? senderId;
  final String? senderAvatarUrl;
  final List<Color> senderNameGradientColors;
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
  final RoomSystemEventType? systemEventType;
  final DateTime? autoDismissAt;
  final String? giftAssetPath;
  final String? imageUrl;
  final String? imageContentType;

  bool get applicationResolved =>
      applicationApproved || applicationRejected || applicationExpired;
  bool get shouldAutoDismiss => autoDismissAt != null;

  ChatEntry copyWith({
    String? senderName,
    String? message,
    String? senderId,
    bool clearSenderId = false,
    String? senderAvatarUrl,
    bool clearSenderAvatarUrl = false,
    List<Color>? senderNameGradientColors,
    int? vipLevel,
    int? sendingLevel,
    int? receivingLevel,
    bool? isGift,
    bool? isSeatApplication,
    int? seatIndex,
    DateTime? applicationCreatedAt,
    DateTime? applicationExpiresAt,
    bool? applicationApproved,
    bool? applicationRejected,
    bool? applicationExpired,
    RoomSystemEventType? systemEventType,
    DateTime? autoDismissAt,
    String? giftAssetPath,
    String? imageUrl,
    String? imageContentType,
  }) {
    return ChatEntry(
      senderName: senderName ?? this.senderName,
      message: message ?? this.message,
      senderId: clearSenderId ? null : senderId ?? this.senderId,
      senderAvatarUrl: clearSenderAvatarUrl
          ? null
          : senderAvatarUrl ?? this.senderAvatarUrl,
      senderNameGradientColors:
          senderNameGradientColors ?? this.senderNameGradientColors,
      vipLevel: vipLevel ?? this.vipLevel,
      sendingLevel: sendingLevel ?? this.sendingLevel,
      receivingLevel: receivingLevel ?? this.receivingLevel,
      isGift: isGift ?? this.isGift,
      isSeatApplication: isSeatApplication ?? this.isSeatApplication,
      seatIndex: seatIndex ?? this.seatIndex,
      applicationCreatedAt: applicationCreatedAt ?? this.applicationCreatedAt,
      applicationExpiresAt: applicationExpiresAt ?? this.applicationExpiresAt,
      applicationApproved: applicationApproved ?? this.applicationApproved,
      applicationRejected: applicationRejected ?? this.applicationRejected,
      applicationExpired: applicationExpired ?? this.applicationExpired,
      systemEventType: systemEventType ?? this.systemEventType,
      autoDismissAt: autoDismissAt ?? this.autoDismissAt,
      giftAssetPath: giftAssetPath ?? this.giftAssetPath,
      imageUrl: imageUrl ?? this.imageUrl,
      imageContentType: imageContentType ?? this.imageContentType,
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
    this.assetUrl,
    this.videoUrl,
    this.categoryKey,
    this.giftType = 'normal',
    this.animationType = 'image',
    this.version = 1,
    this.catalogVersion = 1,
    this.showGiftSlide = true,
    this.showPremiumBroadcast = false,
    this.showGiftFlight = true,
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
  final String? assetUrl;
  final String? videoUrl;
  final String? categoryKey;
  final String giftType;
  final String animationType;
  final int version;
  final int catalogVersion;
  final bool showGiftSlide;
  final bool showPremiumBroadcast;
  final bool showGiftFlight;

  bool get isVideoGift =>
      (videoUrl?.trim().isNotEmpty ?? false) ||
      (videoAssetPath?.trim().isNotEmpty ?? false);
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
    this.giftAssetUrl,
    this.videoUrl,
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
  final String? giftAssetUrl;
  final String? videoUrl;
  final List<Color> colors;
  final int combo;
  final int baseCombo;
  final int remainingSeconds;

  bool get isVideoGift =>
      (videoUrl?.trim().isNotEmpty ?? false) ||
      (videoAssetPath?.trim().isNotEmpty ?? false);

  GiftSlide copyWith({int? combo, int? baseCombo, int? remainingSeconds}) =>
      GiftSlide(
        id: id,
        senderName: senderName,
        receiverName: receiverName,
        giftName: giftName,
        giftIcon: giftIcon,
        giftAssetPath: giftAssetPath,
        videoAssetPath: videoAssetPath,
        giftAssetUrl: giftAssetUrl,
        videoUrl: videoUrl,
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
  if (trimmed.isEmpty) return '?';
  return trimmed.substring(0, 1).toUpperCase();
}

String compactNumber(int value) {
  if (value >= 1000000000) return '${_trimCompactDecimal(value / 1000000000)}B';
  if (value >= 1000000) return '${_trimCompactDecimal(value / 1000000)}M';
  if (value >= 1000) return '${_trimCompactDecimal(value / 1000)}K';
  return '$value';
}

String _trimCompactDecimal(double value) {
  final decimals = value >= 100 ? 0 : value >= 10 ? 1 : 2;
  final fixed = value.toStringAsFixed(decimals);
  return fixed
      .replaceFirst(RegExp(r'\.0+$'), '')
      .replaceFirst(RegExp(r'(\.\d*[1-9])0+$'), r'$1');
}
