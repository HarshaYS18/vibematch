import 'package:flutter/material.dart';

import '../../../core/presentation/vm_skeleton_page.dart';

class LoveBondPage extends StatelessWidget {
  const LoveBondPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VmSkeletonPage(
      title: 'Love & Bond',
      subtitle: 'Relationship cards, lover CP, best friends, brothers, sisters, bond gifts, and relationship status management.',
      icon: Icons.favorite_rounded,
      highlights: [
        'One Lover/CP relationship maximum per user.',
        'Multiple best friends, brothers, and sisters supported.',
        'Relationship cards require request and acceptance flow.',
        'Future backend: relationship requests, accept/reject, remove, gifts, and audit history.',
      ],
    );
  }
}
