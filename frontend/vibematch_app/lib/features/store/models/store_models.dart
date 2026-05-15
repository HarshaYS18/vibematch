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
    required this.priceCoins,
    required this.isOwned,
    required this.isEquipped,
    required this.isFeatured,
    this.description,
    this.assetPath,
    this.imageUrl,
    this.previewUrl,
    this.linkedThemeId,
  });

  final String itemId;
  final String name;
  final String category;
  final String? description;
  final int priceCoins;
  final String? assetPath;
  final String? imageUrl;
  final String? previewUrl;
  final String? linkedThemeId;
  final bool isOwned;
  final bool isEquipped;
  final bool isFeatured;

  bool get isFree => priceCoins <= 0;

  factory StoreItem.fromJson(Map<String, dynamic> json) {
    return StoreItem(
      itemId: json['item_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Store Item',
      category: json['category']?.toString() ?? 'misc',
      description: _nullableString(json['description']),
      priceCoins: int.tryParse(json['price_coins']?.toString() ?? '') ?? 0,
      assetPath: _nullableString(json['asset_path']),
      imageUrl: _nullableString(json['image_url']),
      previewUrl: _nullableString(json['preview_url']),
      linkedThemeId: _nullableString(json['linked_theme_id']),
      isOwned: json['is_owned'] == true,
      isEquipped: json['is_equipped'] == true,
      isFeatured: json['is_featured'] == true,
    );
  }

  StoreItem copyWith({bool? isOwned, bool? isEquipped}) {
    return StoreItem(
      itemId: itemId,
      name: name,
      category: category,
      description: description,
      priceCoins: priceCoins,
      assetPath: assetPath,
      imageUrl: imageUrl,
      previewUrl: previewUrl,
      linkedThemeId: linkedThemeId,
      isOwned: isOwned ?? this.isOwned,
      isEquipped: isEquipped ?? this.isEquipped,
      isFeatured: isFeatured,
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
  final String? assetPath;
  final String? imageUrl;
  final String? previewUrl;
  final String? linkedThemeId;
  final DateTime createdAt;
  final DateTime? expiresAt;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      itemId: json['item_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Inventory Item',
      category: json['category']?.toString() ?? 'misc',
      source: json['source']?.toString() ?? 'purchase',
      isEquipped: json['is_equipped'] == true,
      assetPath: _nullableString(json['asset_path']),
      imageUrl: _nullableString(json['image_url']),
      previewUrl: _nullableString(json['preview_url']),
      linkedThemeId: _nullableString(json['linked_theme_id']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
    );
  }
}

String storeCategoryLabel(String category) {
  return switch (category) {
    'room_background' => 'Room Backgrounds',
    'avatar_frame' => 'Avatar Frames',
    'chat_bubble' => 'Chat Bubbles',
    'entrance_effect' => 'Entrance Effects',
    'profile_theme' => 'Profile Themes',
    'badge' => 'Badges',
    _ => category.replaceAll('_', ' ').trim(),
  };
}

String compactCoins(int value) {
  if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(value % 1000000000 == 0 ? 0 : 1)}B';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
  return '$value';
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}
