import 'package:flutter/material.dart';

import '../../../core/presentation/vm_skeleton_page.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VmSkeletonPage(
      title: 'Search',
      subtitle: 'Search users, official accounts, public rooms, families, events, and allowed numeric IDs.',
      icon: Icons.search_rounded,
      highlights: [
        'Normal users search by public numeric IDs and display names.',
        'Official @names remain reserved for team/staff accounts.',
        'Future backend: privacy-aware search APIs for users, rooms, families, and events.',
      ],
    );
  }
}
