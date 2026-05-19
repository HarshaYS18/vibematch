class StoreCatalog {
  const StoreCatalog({required this.categories, required this.sections});

  final List<String> categories;
  final Map<String, List<StoreItem>> sections;

  factory StoreCatalog.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    final rawSections = json['sections'];
    final sections = <String, List<StoreItem>>{};
    if (rawSections is Map<String, dynamic>) {
      rawSections.forEach((key, value) {
        final items = value is List
            ? value.whereType<Map<String, dynamic>>().map(StoreItem.fromJson).toList(growable: false)
            : <StoreItem>[];
        sections[key] = items;
      });
    }
    return StoreCatalog(
      categories: rawCategories is List ? rawCategories.map((item) => item.toString()).toList(growable: false) : sections.keys.toList(growable: false),
      sections: sections,
    );
  }

  static const empty = StoreCatalog(categories: <String>[], sections: <String, List<StoreItem>>{});
}

class StoreItem {
  const StoreItem({
    required this.itemId,
    required this.name,
    required this.category,
    required this.itemType,
    required this.priceCoins,
    required this.isOwned,
    required this.isEquipped,
    required this.isFeatured,
    this.description,
    this.durationDays,
    this.assetPath,
    this.imageUrl,
    this.previewUrl,
    this.linkedThemeId,
    this.expiresAt,
  });

  final String itemId;
  final String name;
  final String category;
  final String itemType;
  final String? description;
  final int priceCoins;
  final int? durationDays;
  final String? assetPath;
  final String? imageUrl;
  final String? previewUrl;
  final String? linkedThemeId;
  final bool isOwned;
  final bool isEquipped;
  final bool isFeatured;
  final DateTime? expiresAt;

  bool get isFree => priceCoins <= 0;
  bool get isTimed => durationDays != null && durationDays! > 0;
  bool get isConsumable => category == 'love_bond_card' || itemType == 'love_bond_card';

  factory StoreItem.fromJson(Map<String, dynamic> json) {
    return StoreItem(
      itemId: json['item_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Store Item',
      category: json['category']?.toString() ?? 'misc',
      itemType: json['item_type']?.toString() ?? 'store_item',
      description: _nullableString(json['description']),
      priceCoins: int.tryParse(json['price_coins']?.toString() ?? '') ?? 0,
      durationDays: int.tryParse(json['duration_days']?.toString() ?? ''),
      assetPath: _nullableString(json['asset_path']),
      imageUrl: _nullableString(json['image_url']) ?? _nullableString(json['thumbnail_url']) ?? _nullableString(json['cdn_asset_url']),
      previewUrl: _nullableString(json['preview_url']),
      linkedThemeId: _nullableString(json['linked_theme_id']),
      isOwned: json['is_owned'] == true,
      isEquipped: json['is_equipped'] == true,
      isFeatured: json['is_featured'] == true,
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
    );
  }

  StoreItem copyWith({bool? isOwned, bool? isEquipped, DateTime? expiresAt}) {
    return StoreItem(
      itemId: itemId,
      name: name,
      category: category,
      itemType: itemType,
      description: description,
      priceCoins: priceCoins,
      durationDays: durationDays,
      assetPath: assetPath,
      imageUrl: imageUrl,
      previewUrl: previewUrl,
      linkedThemeId: linkedThemeId,
      isOwned: isOwned ?? this.isOwned,
      isEquipped: isEquipped ?? this.isEquipped,
      isFeatured: isFeatured,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

class UserInventory {
  const UserInventory({required this.categories, required this.sections});

  final List<String> categories;
  final Map<String, List<InventoryItem>> sections;

  factory UserInventory.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    final rawSections = json['sections'];
    final sections = <String, List<InventoryItem>>{};
    if (rawSections is Map<String, dynamic>) {
      rawSections.forEach((key, value) {
        final items = value is List
            ? value.whereType<Map<String, dynamic>>().map(InventoryItem.fromJson).toList(growable: false)
            : <InventoryItem>[];
        sections[key] = items;
      });
    }
    return UserInventory(
      categories: rawCategories is List ? rawCategories.map((item) => item.toString()).toList(growable: false) : sections.keys.toList(growable: false),
      sections: sections,
    );
  }

  static const empty = UserInventory(categories: <String>[], sections: <String, List<InventoryItem>>{});
}

class InventoryItem {
  const InventoryItem({
    required this.itemId,
    required this.name,
    required this.category,
    required this.source,
    required this.isEquipped,
    required this.createdAt,
    this.durationDays,
    this.assetPath,
    this.imageUrl,
    this.previewUrl,
    this.linkedThemeId,
    this.expiresAt,
  });

  final String itemId;
  final String name;
  final String category;
  final String source;
  final bool isEquipped;
  final int? durationDays;
  final String? assetPath;
  final String? imageUrl;
  final String? previewUrl;
  final String? linkedThemeId;
  final DateTime createdAt;
  final DateTime? expiresAt;

  bool get isTimed => durationDays != null && durationDays! > 0;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      itemId: json['item_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Inventory Item',
      category: json['category']?.toString() ?? 'misc',
      source: json['source']?.toString() ?? 'purchase',
      isEquipped: json['is_equipped'] == true,
      durationDays: int.tryParse(json['duration_days']?.toString() ?? ''),
      assetPath: _nullableString(json['asset_path']),
      imageUrl: _nullableString(json['image_url']),
      previewUrl: _nullableString(json['preview_url']),
      linkedThemeId: _nullableString(json['linked_theme_id']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
    );
  }
}

class EquippedStoreItems {
  const EquippedStoreItems({this.avatarFrame, this.chatBubble});

  final EquippedStoreItem? avatarFrame;
  final EquippedStoreItem? chatBubble;

  factory EquippedStoreItems.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EquippedStoreItems();
    return EquippedStoreItems(
      avatarFrame: EquippedStoreItem.fromJson(json['avatar_frame'] as Map<String, dynamic>?),
      chatBubble: EquippedStoreItem.fromJson(json['chat_bubble'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'avatar_frame': avatarFrame?.toJson(),
      'chat_bubble': chatBubble?.toJson(),
    };
  }
}

class EquippedStoreItem {
  const EquippedStoreItem({required this.category, this.itemId, this.name, this.assetPath, this.imageUrl, this.expiresAt});

  final String? itemId;
  final String? name;
  final String category;
  final String? assetPath;
  final String? imageUrl;
  final DateTime? expiresAt;

  factory EquippedStoreItem.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EquippedStoreItem(category: '');
    return EquippedStoreItem(
      itemId: _nullableString(json['item_id']),
      name: _nullableString(json['name']),
      category: json['category']?.toString() ?? '',
      assetPath: _nullableString(json['asset_path']),
      imageUrl: _nullableString(json['image_url']),
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
    );
  }

  bool get isEmpty => (itemId == null || itemId!.isEmpty) && (assetPath == null || assetPath!.isEmpty) && (imageUrl == null || imageUrl!.isEmpty);

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'name': name,
      'category': category,
      'asset_path': assetPath,
      'image_url': imageUrl,
      'expires_at': expiresAt?.toIso8601String(),
    };
  }
}

String storeCategoryLabel(String category) {
  return switch (category) {
    'room_background' => 'Room Backgrounds',
    'avatar_frame' => 'Avatar Frames',
    'chat_bubble' => 'Chat Bubbles',
    'entrance_effect' => 'Entrance Effects',
    'profile_theme' => 'Profile Themes',
    'love_bond_card' => 'Love & Bonds',
    'badge' => 'Badges',
    _ => category.replaceAll('_', ' ').trim(),
  };
}

String storeCategoryShortLabel(String category) {
  return switch (category) {
    'room_background' => 'BG',
    'avatar_frame' => 'Frame',
    'chat_bubble' => 'Bubble',
    'entrance_effect' => 'Entry',
    'profile_theme' => 'Theme',
    'love_bond_card' => 'Bond',
    'badge' => 'Badge',
    _ => category.replaceAll('_', ' ').trim(),
  };
}

String compactCoins(int value) {
  if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(value % 1000000000 == 0 ? 0 : 1)}B';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
  return '$value';
}

String expiryLabel(DateTime? expiresAt) {
  if (expiresAt == null) return 'Permanent';
  final now = DateTime.now();
  if (!expiresAt.isAfter(now)) return 'Expired';
  final days = expiresAt.difference(now).inDays;
  if (days <= 0) return 'Expires today';
  return '$days days left';
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}
