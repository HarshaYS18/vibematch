import 'package:flutter/material.dart';

import '../../../core/presentation/vm_skeleton_page.dart';

class AgencyPage extends StatelessWidget {
  const AgencyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VmSkeletonPage(
      title: 'Agency',
      subtitle: 'Agency Owner, Agency Admin, Hosts, BD hierarchy, commission, leave requests, and agency performance.',
      icon: Icons.groups_2_rounded,
      highlights: [
        'Agency Owner can invite, approve, remove hosts, and appoint up to 2 admins.',
        'Agency Admin can invite and approve hosts but cannot remove hosts or manage admins.',
        'Future backend: agency membership, host rewards, commissions, and audit logs.',
      ],
    );
  }
}
