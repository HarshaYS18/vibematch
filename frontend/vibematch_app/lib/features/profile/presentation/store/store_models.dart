import 'package:flutter/material.dart';

enum VmStoreTab { store, mine }

enum VmStoreSection {
  frames('Frames', Icons.filter_frames_rounded),
  entranceEffects('Entrance Effects', Icons.auto_awesome_rounded),
  chatBubble('Chat Bubble', Icons.chat_bubble_rounded),
  roomBackground('Room Background', Icons.wallpaper_rounded),
  specialId('Special ID', Icons.badge_rounded),
  loveAndBondCards('Love & Bond Cards', Icons.favorite_rounded),
  specialItems('Special Items', Icons.diamond_rounded);

  const VmStoreSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum VmStoreItemType {
  frame,
  entranceEffect,
  chatBubble,
  roomBackground,
  specialId,
  loveCard,
  brotherCard,
  sisterCard,
  bestieCard,
  specialItem,
}

enum VmStoreItemRarity {
  common('Common'),
  premium('Premium'),
  vip('VIP'),
  svip('SVIP'),
  limited('Limited'),
  official('Official');

  const VmStoreItemRarity(this.label);
  final String label;
}

class VmStoreItem {
  const VmStoreItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.section,
    required this.type,
    required this.rarity,
    required this.priceCoins,
    required this.isDynamicRemoteItem,
    required this.isLimited,
    required this.previewAssetKey,
    required this.colors,
    this.requiredVipLevel = 0,
    this.requiredSvipLevel = 0,
    this.durationDays,
    this.maxOwnable,
  });

  final String id;
  final String title;
  final String subtitle;
  final VmStoreSection section;
  final VmStoreItemType type;
  final VmStoreItemRarity rarity;
  final int priceCoins;
  final bool isDynamicRemoteItem;
  final bool isLimited;
  final String previewAssetKey;
  final List<Color> colors;
  final int requiredVipLevel;
  final int requiredSvipLevel;
  final int? durationDays;
  final int? maxOwnable;

  bool get isFree => priceCoins <= 0;
}

class VmStoreInventoryEntry {
  const VmStoreInventoryEntry({
    required this.itemId,
    required this.ownedAt,
    this.expiresAt,
    this.isEquipped = false,
  });

  final String itemId;
  final DateTime ownedAt;
  final DateTime? expiresAt;
  final bool isEquipped;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  VmStoreInventoryEntry copyWith({bool? isEquipped}) {
    return VmStoreInventoryEntry(
      itemId: itemId,
      ownedAt: ownedAt,
      expiresAt: expiresAt,
      isEquipped: isEquipped ?? this.isEquipped,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'item_id': itemId,
      'owned_at': ownedAt.toIso8601String(),
      if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
      'is_equipped': isEquipped,
    };
  }

  factory VmStoreInventoryEntry.fromJson(Map<String, dynamic> json) {
    return VmStoreInventoryEntry(
      itemId: json['item_id']?.toString() ?? '',
      ownedAt: DateTime.tryParse(json['owned_at']?.toString() ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
      isEquipped: json['is_equipped'] == true,
    );
  }
}

class VmStoreUserState {
  const VmStoreUserState({
    required this.coinBalance,
    required this.hasLoveRelationship,
    required this.inventory,
  });

  final int coinBalance;
  final bool hasLoveRelationship;
  final List<VmStoreInventoryEntry> inventory;

  Set<String> get ownedItemIds => inventory.where((item) => !item.isExpired).map((item) => item.itemId).toSet();

  bool owns(String itemId) => ownedItemIds.contains(itemId);

  VmStoreUserState copyWith({
    int? coinBalance,
    bool? hasLoveRelationship,
    List<VmStoreInventoryEntry>? inventory,
  }) {
    return VmStoreUserState(
      coinBalance: coinBalance ?? this.coinBalance,
      hasLoveRelationship: hasLoveRelationship ?? this.hasLoveRelationship,
      inventory: inventory ?? this.inventory,
    );
  }
}
