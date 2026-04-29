import 'package:flutter/material.dart';

import '../../../core/presentation/vm_skeleton_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VmSkeletonPage(
      title: 'Notifications',
      subtitle: 'Room invites, reactions, mentions, official updates, event alerts, and safety/system messages.',
      icon: Icons.notifications_rounded,
      highlights: [
        'Room invites should route back into Inbox conversations.',
        'Vibes reactions, comments, mentions, and @all alerts.',
        'Future backend: notification inbox, read state, and push routing APIs.',
      ],
    );
  }
}
