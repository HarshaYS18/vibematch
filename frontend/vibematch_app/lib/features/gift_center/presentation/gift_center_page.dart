import 'package:flutter/material.dart';

import '../../../core/presentation/vm_skeleton_page.dart';

class GiftCenterPage extends StatelessWidget {
  const GiftCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VmSkeletonPage(
      title: 'Gifts',
      subtitle: 'Gift catalog, normal gifts, lucky gifts, relationship gifts, premium animations, combo history, and received gifts.',
      icon: Icons.card_giftcard_rounded,
      highlights: [
        'Gift catalog must come from backend before production testing.',
        'Gift sending must be wallet-ledger and WebSocket controlled.',
        'Future backend: gift catalog, send gift, combo, received gift, and lucky gift APIs.',
      ],
    );
  }
}
