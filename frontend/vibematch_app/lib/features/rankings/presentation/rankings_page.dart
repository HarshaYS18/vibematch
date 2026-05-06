import 'package:flutter/material.dart';

import '../../../core/presentation/vm_skeleton_page.dart';

class RankingsPage extends StatelessWidget {
  const RankingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VmSkeletonPage(
      title: 'Rankings',
      subtitle: 'Global sent and received rankings with hourly, daily, weekly, and monthly filters.',
      icon: Icons.leaderboard_rounded,
      highlights: [
        'Sent Rankings and Received Rankings.',
        'Filters: this hour, today, this week, this month.',
        'Future backend: paginated ranking APIs and user rank position.',
      ],
    );
  }
}
