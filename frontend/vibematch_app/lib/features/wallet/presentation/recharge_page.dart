import 'package:flutter/material.dart';

import '../../../core/presentation/vm_skeleton_page.dart';

class RechargePage extends StatelessWidget {
  const RechargePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VmSkeletonPage(
      title: 'Recharge',
      subtitle: 'Coin recharge, packages, payment status, bonus campaigns, and safe test recharge flow.',
      icon: Icons.add_card_rounded,
      highlights: [
        'Recharge must create wallet ledger entries server-side.',
        'Payments and test credits must be clearly separated.',
        'Future backend: recharge packages, payment callbacks, and fraud checks.',
      ],
    );
  }
}
