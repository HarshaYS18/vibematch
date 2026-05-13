import 'package:flutter/material.dart';

import '../../live_room_models.dart';

class RoomGiftCategoryModule {
  const RoomGiftCategoryModule({
    required this.category,
    required this.label,
    required this.icon,
    required this.description,
    required this.comboOptions,
    required this.backendKey,
  });

  final GiftCategory category;
  final String label;
  final IconData icon;
  final String description;
  final List<int> comboOptions;
  final String backendKey;

  bool get isInventoryCategory => category == GiftCategory.baggage;
  bool get isLuckyCategory => category == GiftCategory.lucky;
}

class RoomGiftCategoryRegistry {
  const RoomGiftCategoryRegistry._();

  static const classic = RoomGiftCategoryModule(
    category: GiftCategory.classic,
    label: 'Classic',
    icon: Icons.card_giftcard_rounded,
    description: 'Fast lightweight room gifts.',
    comboOptions: [1, 9, 69, 99, 999],
    backendKey: 'classic',
  );

  static const lucky = RoomGiftCategoryModule(
    category: GiftCategory.lucky,
    label: 'Lucky',
    icon: Icons.casino_rounded,
    description: 'Lucky gifts with special rules.',
    comboOptions: [9, 69, 99, 999],
    backendKey: 'lucky',
  );

  static const relationship = RoomGiftCategoryModule(
    category: GiftCategory.relationship,
    label: 'Relationship',
    icon: Icons.favorite_rounded,
    description: 'Love and relationship gifts.',
    comboOptions: [1, 9, 69, 99, 999],
    backendKey: 'relationship',
  );

  static const event = RoomGiftCategoryModule(
    category: GiftCategory.event,
    label: 'Event',
    icon: Icons.celebration_rounded,
    description: 'Seasonal and event gifts.',
    comboOptions: [1, 9, 69, 99, 999],
    backendKey: 'event',
  );

  static const premium = RoomGiftCategoryModule(
    category: GiftCategory.premium,
    label: 'Premium',
    icon: Icons.auto_awesome_rounded,
    description: 'High value premium gifts.',
    comboOptions: [1, 9, 69, 99, 999],
    backendKey: 'premium',
  );

  static const svip = RoomGiftCategoryModule(
    category: GiftCategory.svip,
    label: 'SVIP',
    icon: Icons.diamond_rounded,
    description: 'Monthly SVIP exclusive gifts.',
    comboOptions: [1, 9, 69, 99, 999],
    backendKey: 'svip',
  );

  static const vip = RoomGiftCategoryModule(
    category: GiftCategory.vip,
    label: 'VIP',
    icon: Icons.workspace_premium_rounded,
    description: 'Recharge VIP exclusive gifts.',
    comboOptions: [1, 9, 69, 99, 999],
    backendKey: 'vip',
  );

  static const baggage = RoomGiftCategoryModule(
    category: GiftCategory.baggage,
    label: 'Baggage',
    icon: Icons.inventory_2_rounded,
    description: 'Owned gift inventory.',
    comboOptions: [1, 9, 69, 99, 999],
    backendKey: 'baggage',
  );

  static const modules = <RoomGiftCategoryModule>[
    classic,
    lucky,
    relationship,
    event,
    premium,
    svip,
    vip,
    baggage,
  ];

  static RoomGiftCategoryModule moduleFor(GiftCategory category) {
    return modules.firstWhere((item) => item.category == category, orElse: () => classic);
  }
}
