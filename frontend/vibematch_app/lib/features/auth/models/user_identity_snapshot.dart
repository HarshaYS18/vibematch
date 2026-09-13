import '../../profile/models/vip_wallet_models.dart';
import 'role_badge.dart';

/// Immutable normalized projection of backend-authoritative user identity data.
///
/// This is intentionally not a cache or mutable store. Backend services remain
/// the source of truth; this model only gives every Flutter feature one parser
/// for identity, role, VIP, level, and equipped-cosmetic fields.
class UserIdentitySnapshot {
  const UserIdentitySnapshot({
    required this.backendUserId,
    required this.publicUserId,
    required this.displayCustomId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.primaryRole,
    required this.primaryRoleBadge,
    required this.roleBadges,
    required this.vip,
    required this.sendLevel,
    required this.receiveLevel,
    required this.sentExp,
    required this.receivedExp,
    required this.equippedItems,
  });

  final int backendUserId;
  final int publicUserId;
  final int? displayCustomId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String primaryRole;
  final RoleBadge? primaryRoleBadge;
  final List<RoleBadge> roleBadges;
  final UserVipSummary vip;
  final int sendLevel;
  final int receiveLevel;
  final int sentExp;
  final int receivedExp;
  final UserEquippedItemsSnapshot equippedItems;

  String get visibleName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) return handle;
    return 'Vibe User';
  }

  String get visibleId =>
      (displayCustomId != null && displayCustomId! > 0)
          ? displayCustomId.toString()
          : publicUserId > 0
          ? publicUserId.toString()
          : '';

  String get roomUserId =>
      publicUserId > 0 ? 'user_$publicUserId' : 'user_$backendUserId';

  String get roleDisplayLabel {
    final backendLabel = primaryRoleBadge?.displayTitle.trim();
    if (backendLabel != null && backendLabel.isNotEmpty) return backendLabel;
    final fallback = RoleBadge.fromRole(primaryRole).displayTitle.trim();
    return fallback == 'User' ? '' : fallback;
  }

  factory UserIdentitySnapshot.fromJson(Map<String, dynamic> json) {
    final identity = _firstMap(json, const [
      'identity',
      'user',
      'author',
      'profile',
    ]);
    final source = <String, dynamic>{...identity, ...json};

    final profileSummary = _firstMap(json, const ['profile_summary']);
    final rolesContainer = _firstMap(json, const ['roles']);
    final wallet = _firstMap(source, const ['wallet']);
    final levels = _firstMap(json, const ['levels']);
    final contribution = _firstMap(json, const ['contribution']);

    final vipJson = _firstNonEmptyMap([
      _firstMap(source, const ['vip']),
      _firstMap(profileSummary, const ['vip']),
    ]);

    final primaryRole =
        _text(source, const ['primary_role', 'primaryRole']) ??
        _text(rolesContainer, const ['primary_role', 'primaryRole']) ??
        'user';

    final primaryBadgeRaw =
        _mapOrNull(source['primary_role_badge']) ??
        _mapOrNull(source['primaryRoleBadge']) ??
        _mapOrNull(rolesContainer['primary_role_badge']) ??
        _mapOrNull(rolesContainer['primaryRoleBadge']);

    final roleBadgesRaw =
        source['role_badges'] ??
        source['roleBadges'] ??
        rolesContainer['role_badges'] ??
        rolesContainer['roleBadges'];

    final parsedRoleBadges = roleBadgesRaw is List
        ? roleBadgesRaw
              .whereType<Map>()
              .map((item) => RoleBadge.fromJson(item.cast<String, dynamic>()))
              .toList(growable: false)
        : const <RoleBadge>[];

    final sentLevel = _firstInt([
      source['sending_level'],
      source['sendingLevel'],
      source['send_level'],
      source['sent_level'],
      wallet['send_level'],
      wallet['sent_level'],
      _map(wallet['sent'])['level'],
      levels['send_level'],
      levels['sent_level'],
    ]);
    final receivedLevel = _firstInt([
      source['receiving_level'],
      source['receivingLevel'],
      source['receive_level'],
      source['received_level'],
      wallet['receive_level'],
      wallet['received_level'],
      _map(wallet['received'])['level'],
      levels['receive_level'],
      levels['received_level'],
    ]);

    final sentExp = _firstInt([
      source['sent_exp'],
      source['sentExp'],
      source['monthly_gift_coins_sent'],
      wallet['monthly_gift_coins_sent'],
      contribution['monthly_sent_coins'],
      levels['send_exp'],
    ]);
    final receivedExp = _firstInt([
      source['received_exp'],
      source['receivedExp'],
      source['monthly_gift_coins_received'],
      wallet['monthly_gift_coins_received'],
      contribution['monthly_received_coins'],
      levels['receive_exp'],
    ]);

    final equippedRaw =
        _mapOrNull(source['equipped_items']) ??
        _mapOrNull(source['equippedItems']) ??
        const <String, dynamic>{};

    return UserIdentitySnapshot(
      backendUserId: _firstInt([
        source['backend_user_id'],
        source['user_id'],
        source['id'],
      ]),
      publicUserId: _firstInt([
        source['public_user_id'],
        source['publicUserId'],
      ]),
      displayCustomId: _firstNullableInt([
        source['display_custom_id'],
        source['displayCustomId'],
      ]),
      username: _text(source, const ['username']),
      displayName: _text(source, const ['display_name', 'displayName']),
      avatarUrl: _text(source, const ['avatar_url', 'avatarUrl']),
      primaryRole: primaryRole,
      primaryRoleBadge: primaryBadgeRaw == null
          ? null
          : RoleBadge.fromJson(primaryBadgeRaw),
      roleBadges: parsedRoleBadges,
      vip: UserVipSummary.fromJson(vipJson.isEmpty ? null : vipJson),
      sendLevel: sentLevel,
      receiveLevel: receivedLevel,
      sentExp: sentExp,
      receivedExp: receivedExp,
      equippedItems: UserEquippedItemsSnapshot.fromJson(equippedRaw),
    );
  }
}

class UserEquippedItemsSnapshot {
  const UserEquippedItemsSnapshot({
    this.avatarFrame,
    this.chatBubble,
    this.textBubble,
    this.entranceEffect,
    this.profileDecoration,
    this.nameGradient,
  });

  final UserEquippedItemSnapshot? avatarFrame;
  final UserEquippedItemSnapshot? chatBubble;
  final UserEquippedItemSnapshot? textBubble;
  final UserEquippedItemSnapshot? entranceEffect;
  final UserEquippedItemSnapshot? profileDecoration;
  final UserEquippedItemSnapshot? nameGradient;

  const UserEquippedItemsSnapshot.empty()
      : avatarFrame = null,
        chatBubble = null,
        textBubble = null,
        entranceEffect = null,
        profileDecoration = null,
        nameGradient = null;

  factory UserEquippedItemsSnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const UserEquippedItemsSnapshot.empty();
    }
    return UserEquippedItemsSnapshot(
      avatarFrame: UserEquippedItemSnapshot.fromDynamic(
        json['avatar_frame'] ?? json['avatarFrame'],
      ),
      chatBubble: UserEquippedItemSnapshot.fromDynamic(
        json['chat_bubble'] ?? json['chatBubble'],
      ),
      textBubble: UserEquippedItemSnapshot.fromDynamic(
        json['text_bubble'] ?? json['textBubble'],
      ),
      entranceEffect: UserEquippedItemSnapshot.fromDynamic(
        json['entrance_effect'] ?? json['entranceEffect'],
      ),
      profileDecoration: UserEquippedItemSnapshot.fromDynamic(
        json['profile_decoration'] ?? json['profileDecoration'],
      ),
      nameGradient: UserEquippedItemSnapshot.fromDynamic(
        json['name_gradient'] ?? json['nameGradient'],
      ),
    );
  }
}

class UserEquippedItemSnapshot {
  const UserEquippedItemSnapshot({
    required this.itemId,
    required this.name,
    required this.category,
    required this.assetPath,
    required this.cdnAssetUrl,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.expiresAt,
  });

  final String? itemId;
  final String? name;
  final String? category;
  final String? assetPath;
  final String? cdnAssetUrl;
  final String? imageUrl;
  final String? thumbnailUrl;
  final DateTime? expiresAt;

  String? get bestImageUrl {
    for (final value in [cdnAssetUrl, imageUrl, thumbnailUrl]) {
      final clean = value?.trim();
      if (clean != null && clean.isNotEmpty) return clean;
    }
    return null;
  }

  static UserEquippedItemSnapshot? fromDynamic(dynamic raw) {
    final json = _mapOrNull(raw);
    if (json == null || json.isEmpty) return null;
    return UserEquippedItemSnapshot(
      itemId: _text(json, const ['item_id', 'itemId']),
      name: _text(json, const ['name']),
      category: _text(json, const ['category']),
      assetPath: _text(json, const ['asset_path', 'assetPath']),
      cdnAssetUrl: _text(json, const ['cdn_asset_url', 'cdnAssetUrl']),
      imageUrl: _text(json, const ['image_url', 'imageUrl']),
      thumbnailUrl: _text(json, const ['thumbnail_url', 'thumbnailUrl']),
      expiresAt: _date(json['expires_at'] ?? json['expiresAt']),
    );
  }
}

Map<String, dynamic> _firstMap(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final key in keys) {
    final value = _mapOrNull(json[key]);
    if (value != null && value.isNotEmpty) return value;
  }
  return const <String, dynamic>{};
}

Map<String, dynamic> _firstNonEmptyMap(List<Map<String, dynamic>> maps) {
  for (final map in maps) {
    if (map.isNotEmpty) return map;
  }
  return const <String, dynamic>{};
}

Map<String, dynamic> _map(dynamic value) =>
    _mapOrNull(value) ?? const <String, dynamic>{};

Map<String, dynamic>? _mapOrNull(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

String? _text(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final text = json[key]?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

int _firstInt(List<dynamic> values) {
  for (final value in values) {
    final parsed = _nullableInt(value);
    if (parsed != null) return parsed < 0 ? 0 : parsed;
  }
  return 0;
}

int? _firstNullableInt(List<dynamic> values) {
  for (final value in values) {
    final parsed = _nullableInt(value);
    if (parsed != null) return parsed;
  }
  return null;
}

int? _nullableInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}
