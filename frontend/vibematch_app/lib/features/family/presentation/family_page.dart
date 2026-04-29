import 'package:flutter/material.dart';

import '../../../core/presentation/vm_skeleton_page.dart';

class FamilyPage extends StatelessWidget {
  const FamilyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VmSkeletonPage(
      title: 'Family',
      subtitle: 'Family groups, members, family contribution, family rooms, levels, rankings, and family events.',
      icon: Icons.diversity_3_rounded,
      highlights: [
        'Family profile, members, contribution, and family rooms.',
        'Family-vs-family activities and event rewards.',
        'Future backend: family membership, rank, event, and anti-abuse APIs.',
      ],
    );
  }
}
