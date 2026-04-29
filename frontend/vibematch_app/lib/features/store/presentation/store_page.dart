import 'package:flutter/material.dart';

import '../../../core/presentation/vm_skeleton_page.dart';

class StorePage extends StatelessWidget {
  const StorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VmSkeletonPage(
      title: 'Store',
      subtitle: 'Avatar frames, room backgrounds, entrance effects, chat bubbles, relationship cards, and custom IDs.',
      icon: Icons.storefront_rounded,
      highlights: [
        'Store categories remain separate from wallet accounting.',
        'Custom numeric display IDs and cosmetic inventory.',
        'Future backend: product catalog, purchase, inventory, equip APIs.',
      ],
    );
  }
}
