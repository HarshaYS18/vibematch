import 'package:flutter/foundation.dart';

class LiveRoomSystemEventBus {
  LiveRoomSystemEventBus._();

  static final ValueNotifier<LiveRoomSystemEvent?> latestEvent =
      ValueNotifier<LiveRoomSystemEvent?>(null);

  static void publish(LiveRoomSystemEvent event) {
    latestEvent.value = event;
  }
}

class LiveRoomSystemEvent {
  const LiveRoomSystemEvent({
    required this.id,
    required this.type,
    required this.roomId,
    required this.actorUserId,
    required this.actorName,
    required this.targetUserId,
    required this.targetName,
    required this.createdAt,
    this.message = '',
    this.actorAvatarUrl,
    this.actorVipLevel = 0,
    this.actorSendingLevel = 0,
    this.actorReceivingLevel = 0,
    this.autoDismissSeconds,
    this.giftId = '',
    this.giftName = '',
    this.giftAssetUrl,
    this.giftVideoUrl,
    this.giftAssetPath,
    this.giftVideoAssetPath,
    this.giftCategory = 'classic',
    this.giftType = 'normal',
    this.animationType = 'image',
    this.giftVersion = 1,
    this.catalogVersion = 1,
    this.giftQuantity = 0,
    this.giftCoinValue = 0,
    this.giftTotalCoinValue = 0,
    this.isLuckyGift = false,
    this.luckyMultiplier = 0,
    this.luckyRewardCoinAmount = 0,
    this.ribbonTier = 'normal',
    this.broadcastScope = 'room',
    this.showGiftSlide = true,
    this.showPremiumBroadcast = false,
    this.showGiftFlight = true,
  });

  final String id;
  final String type;
  final String roomId;
  final String actorUserId;
  final String actorName;
  final String targetUserId;
  final String targetName;
  final String message;
  final String? actorAvatarUrl;
  final int actorVipLevel;
  final int actorSendingLevel;
  final int actorReceivingLevel;
  final DateTime createdAt;
  final int? autoDismissSeconds;
  final String giftId;
  final String giftName;
  final String? giftAssetUrl;
  final String? giftVideoUrl;
  final String? giftAssetPath;
  final String? giftVideoAssetPath;
  final String giftCategory;
  final String giftType;
  final String animationType;
  final int giftVersion;
  final int catalogVersion;
  final int giftQuantity;
  final int giftCoinValue;
  final int giftTotalCoinValue;
  final bool isLuckyGift;
  final int luckyMultiplier;
  final int luckyRewardCoinAmount;
  final String ribbonTier;
  final String broadcastScope;
  final bool showGiftSlide;
  final bool showPremiumBroadcast;
  final bool showGiftFlight;

  bool get isUserEntered => type == 'user_entered';
  bool get isUserRemoved => type == 'user_removed';
  bool get isRoomSystemMessage => type == 'room_system_message';
  bool get isRoomChatMessage => type == 'room_chat_message';
  bool get isRoomGiftSent => type == 'room_gift_sent';
  bool get isChatCleared => type == 'chat_cleared';

  factory LiveRoomSystemEvent.fromJson(Map<String, dynamic> json) {
    final rawAutoDismiss = json['auto_dismiss_seconds'];
    final ribbonTier = (json['ribbon_tier'] ?? json['ribbonTier'] ?? 'normal').toString();
    final broadcastScope = (json['broadcast_scope'] ?? json['broadcastScope'] ?? 'room').toString();
    return LiveRoomSystemEvent(
      id:
          json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      type: json['event_type']?.toString() ?? json['type']?.toString() ?? '',
      roomId: json['room_id']?.toString() ?? '',
      actorUserId: json['actor_user_id']?.toString() ?? '',
      actorName: json['actor_name']?.toString() ?? '',
      targetUserId: json['target_user_id']?.toString() ?? '',
      targetName: json['target_name']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      actorAvatarUrl: _text(json['actor_avatar_url'] ?? json['actorAvatarUrl']),
      actorVipLevel: _int(json['actor_vip_level'] ?? json['actorVipLevel']),
      actorSendingLevel: _int(
        json['actor_sending_level'] ?? json['actorSendingLevel'],
      ),
      actorReceivingLevel: _int(
        json['actor_receiving_level'] ?? json['actorReceivingLevel'],
      ),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      autoDismissSeconds: rawAutoDismiss == null
          ? null
          : int.tryParse(rawAutoDismiss.toString()),
      giftId: json['gift_id']?.toString() ?? '',
      giftName: json['gift_name']?.toString() ?? '',
      giftAssetUrl: _text(json['asset_url'] ?? json['gift_asset_url'] ?? json['giftAssetUrl']),
      giftVideoUrl: _text(json['video_url'] ?? json['gift_video_url'] ?? json['giftVideoUrl']),
      giftAssetPath: _text(json['asset_path'] ?? json['gift_asset_path'] ?? json['giftAssetPath']),
      giftVideoAssetPath: _text(json['video_asset_path'] ?? json['gift_video_asset_path'] ?? json['giftVideoAssetPath']),
      giftCategory: (json['gift_category'] ?? json['category'] ?? 'classic').toString(),
      giftType: (json['gift_type'] ?? 'normal').toString(),
      animationType: (json['animation_type'] ?? 'image').toString(),
      giftVersion: _int(json['gift_version'] ?? json['version']),
      catalogVersion: _int(json['catalog_version']),
      giftQuantity: _int(json['quantity'] ?? json['gift_quantity']),
      giftCoinValue: _int(json['coin_value'] ?? json['gift_coin_value']),
      giftTotalCoinValue: _int(
        json['total_coin_value'] ?? json['gift_total_coin_value'],
      ),
      isLuckyGift: json['is_lucky'] == true || json['is_lucky_gift'] == true || (json['gift_type']?.toString() == 'lucky'),
      luckyMultiplier: _int(json['lucky_multiplier']),
      luckyRewardCoinAmount: _int(json['lucky_reward_coin_amount']),
      ribbonTier: ribbonTier,
      broadcastScope: broadcastScope,
      showGiftSlide: _bool(json['show_gift_slide'] ?? json['showGiftSlide'], fallback: true),
      showPremiumBroadcast: _bool(
        json['show_premium_broadcast'] ?? json['showPremiumBroadcast'],
        fallback: ribbonTier == 'premium' || broadcastScope == 'global',
      ),
      showGiftFlight: _bool(json['show_gift_flight'] ?? json['showGiftFlight'], fallback: true),
    );
  }
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty || text == 'null' ? null : text;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

bool _bool(dynamic value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final clean = value.trim().toLowerCase();
    if (clean == 'true' || clean == '1' || clean == 'yes') return true;
    if (clean == 'false' || clean == '0' || clean == 'no') return false;
  }
  return fallback;
}
