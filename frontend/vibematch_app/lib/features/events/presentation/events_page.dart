import 'package:flutter/material.dart';

import '../../../core/presentation/vm_skeleton_page.dart';

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VmSkeletonPage(
      title: 'Events',
      subtitle: 'Official Vibe Match events, banners, rewards, badges, free frames, and seasonal campaigns will live here.',
      icon: Icons.celebration_rounded,
      highlights: [
        'Event banners from Home route here.',
        'Event details, rules, rewards, rankings, and badges.',
        'Future backend: active, upcoming, expired-preview event APIs.',
      ],
    );
  }
}
