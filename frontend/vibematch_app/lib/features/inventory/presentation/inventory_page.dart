import 'package:flutter/material.dart';

import '../../../core/presentation/vm_skeleton_page.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VmSkeletonPage(
      title: 'Inventory',
      subtitle: 'Owned avatar frames, entrance effects, chat bubbles, room backgrounds, VIP items, and equipped cosmetics.',
      icon: Icons.inventory_2_rounded,
      highlights: [
        'Inventory should show owned and equipped items separately.',
        'Cosmetics should apply to profile, seats, chat, moments, and room entry.',
        'Future backend: inventory, equip, expiry, and ownership APIs.',
      ],
    );
  }
}
