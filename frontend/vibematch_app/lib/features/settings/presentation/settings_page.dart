import 'package:flutter/material.dart';

import '../../../core/presentation/vm_skeleton_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VmSkeletonPage(
      title: 'Settings',
      subtitle: 'Account, privacy, notifications, blocked users, security, language, and app preferences.',
      icon: Icons.settings_rounded,
      highlights: [
        'Privacy controls and stranger message rules.',
        'Blocked users, notification settings, and account security.',
        'Future backend: user preferences and privacy APIs.',
      ],
    );
  }
}
