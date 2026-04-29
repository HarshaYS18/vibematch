import 'package:flutter/material.dart';

import '../../../core/presentation/vm_skeleton_page.dart';

class ControlCenterPage extends StatelessWidget {
  const ControlCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VmSkeletonPage(
      title: 'Control Center',
      subtitle: 'Role-specific official dashboards for Founder, Owner, SuperAdmin, Admin, Monitor, CS, Agency, BD, and merchants.',
      icon: Icons.admin_panel_settings_rounded,
      highlights: [
        'Every control center action must be backend permission checked.',
        'Sensitive actions must be audit logged.',
        'Future backend: role-scoped dashboard APIs and moderation queues.',
      ],
    );
  }
}
