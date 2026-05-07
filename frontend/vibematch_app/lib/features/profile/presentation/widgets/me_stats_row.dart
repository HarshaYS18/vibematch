import 'package:flutter/material.dart';

import 'me_shared_widgets.dart';

class MeStatsRow extends StatelessWidget {
  const MeStatsRow({
    super.key,
    required this.onFollowingTap,
    required this.onFollowersTap,
    required this.onRoomsTap,
    required this.onVisitorsTap,
  });

  final VoidCallback onFollowingTap;
  final VoidCallback onFollowersTap;
  final VoidCallback onRoomsTap;
  final VoidCallback onVisitorsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MeProfileStat(
          label: 'Following',
          value: '128',
          icon: Icons.people_alt_rounded,
          onTap: onFollowingTap,
        ),
        const SizedBox(width: 7),
        MeProfileStat(
          label: 'Followers',
          value: '3.4K',
          icon: Icons.favorite_rounded,
          onTap: onFollowersTap,
        ),
        const SizedBox(width: 7),
        MeProfileStat(
          label: 'Rooms',
          value: '12',
          icon: Icons.mic_rounded,
          onTap: onRoomsTap,
        ),
        const SizedBox(width: 7),
        MeProfileStat(
          label: 'Visitors',
          value: '296',
          icon: Icons.visibility_rounded,
          onTap: onVisitorsTap,
        ),
      ],
    );
  }
}
