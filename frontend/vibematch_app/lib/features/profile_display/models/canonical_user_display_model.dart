class CanonicalUserDisplayModel {
  const CanonicalUserDisplayModel({
    required this.backendUserId,
    required this.publicUserId,
    required this.displayName,
    required this.primaryRole,
    required this.roomRoleLabel,
    required this.vipLevel,
    required this.svipLevel,
    required this.sentLevel,
    required this.receivedLevel,
    required this.monthlySentCoins,
    required this.monthlyReceivedCoins,
    required this.totalSentCoins,
    required this.totalReceivedCoins,
    required this.nameGradientColors,
    required this.equippedItems,
    this.displayCustomId,
    this.username,
    this.avatarUrl,
    this.coverPhotoUrl,
    this.verifiedOfficial = false,
    this.isRoomHost = false,
    this.isRoomAdmin = false,
    this.isRoomMember = false,
    this.adminMuted = false,
  });

  final int backendUserId;
  final int publicUserId;
  final int? displayCustomId;
  final String? username;
  final String displayName;
  final String? avatarUrl;
  final String? coverPhotoUrl;
  final String primaryRole;
  final String roomRoleLabel;
  final bool verifiedOfficial;
  final bool isRoomHost;
  final bool isRoomAdmin;
  final bool isRoomMember;
  final bool adminMuted;
  final int vipLevel;
  final int svipLevel;
  final int sentLevel;
  final int receivedLevel;
  final int monthlySentCoins;
  final int monthlyReceivedCoins;
  final int totalSentCoins;
  final int totalReceivedCoins;
  final List<String> nameGradientColors;
  final Map<String, CanonicalEquippedItem> equippedItems;

  CanonicalEquippedItem? get avatarFrame => equippedItems['avatar_frame'];
  CanonicalEquippedItem? get textBubble =>
      equippedItems['text_bubble'] ?? equippedItems['chat_bubble'];
  CanonicalEquippedItem? get entranceEffect => equippedItems['entrance_effect'];
  CanonicalEquippedItem? get profileDecoration =>
      equippedItems['profile_decoration'];

  factory CanonicalUserDisplayModel.fromJson(Map<String, dynamic> json) {
    final gradient = _map(json['name_gradient']);
    final equipped = _map(json['equipped_items']);
    final items = <String, CanonicalEquippedItem>{};
    equipped.forEach((key, value) {
      final itemMap = _map(value);
      if (itemMap.isNotEmpty)
        items[key] = CanonicalEquippedItem.fromJson(itemMap);
    });
    return CanonicalUserDisplayModel(
      backendUserId: _int(json['backend_user_id']),
      publicUserId: _int(json['public_user_id']),
      displayCustomId: json['display_custom_id'] == null
          ? null
          : _int(json['display_custom_id']),
      username: _text(json['username']),
      displayName: _text(json['display_name']) ?? 'FunKey User',
      avatarUrl: _text(json['avatar_url']),
      coverPhotoUrl: _text(json['cover_photo_url']),
      primaryRole: _text(json['primary_role']) ?? 'user',
      roomRoleLabel: _text(json['room_role_label']) ?? '',
      verifiedOfficial: json['verified_official'] == true,
      isRoomHost: json['is_room_host'] == true,
      isRoomAdmin: json['is_room_admin'] == true,
      isRoomMember: json['is_room_member'] == true,
      adminMuted: json['admin_muted'] == true,
      vipLevel: _int(json['vip_level']),
      svipLevel: _int(json['svip_level']),
      sentLevel: _int(json['sent_level']),
      receivedLevel: _int(json['received_level']),
      monthlySentCoins: _int(json['monthly_sent_coins']),
      monthlyReceivedCoins: _int(json['monthly_received_coins']),
      totalSentCoins: _int(json['total_sent_coins']),
      totalReceivedCoins: _int(json['total_received_coins']),
      nameGradientColors: _stringList(gradient['colors']),
      equippedItems: items,
    );
  }
}

class CanonicalEquippedItem {
  const CanonicalEquippedItem({
    required this.category,
    this.itemId,
    this.name,
    this.assetPath,
    this.cdnAssetUrl,
    this.imageUrl,
    this.thumbnailUrl,
  });

  final String category;
  final String? itemId;
  final String? name;
  final String? assetPath;
  final String? cdnAssetUrl;
  final String? imageUrl;
  final String? thumbnailUrl;

  String? get preferredImage =>
      imageUrl ?? cdnAssetUrl ?? thumbnailUrl ?? assetPath;

  factory CanonicalEquippedItem.fromJson(Map<String, dynamic> json) {
    return CanonicalEquippedItem(
      category: _text(json['category']) ?? '',
      itemId: _text(json['item_id']),
      name: _text(json['name']),
      assetPath: _text(json['asset_path']),
      cdnAssetUrl: _text(json['cdn_asset_url']),
      imageUrl: _text(json['image_url']),
      thumbnailUrl: _text(json['thumbnail_url']),
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item.toString())
      .where((item) => item.trim().isNotEmpty)
      .toList(growable: false);
}

String? _text(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
