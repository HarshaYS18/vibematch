import 'package:flutter/material.dart';

import '../../../core/presentation/vm_skeleton_page.dart';

class VipPage extends StatelessWidget {
  const VipPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VmSkeletonPage(
      title: 'VIP & SVIP',
      subtitle: 'VIP levels, SVIP monthly status, frozen VIP display, recharge requirements, and premium benefits.',
      icon: Icons.workspace_premium_rounded,
      highlights: [
        'VIP is long-term recharge-based status.',
        'SVIP is monthly recharge-based temporary status.',
        'Future backend: VIP level, frozen status, reactivation, and benefit APIs.',
      ],
    );
  }
}
