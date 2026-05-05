import 'package:flutter/material.dart';

import 'me_shared_widgets.dart';

class MeStatsRow extends StatelessWidget {
  const MeStatsRow({
    super.key,
    required this.onAction,
  });

  final void Function(String message) onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MeProfileStat(
          label: 'Following',
          value: '128',
          icon: Icons.people_alt_rounded,
          onTap: () => onAction('Following list will open.'),
        ),
        const SizedBox(width: 7),
        MeProfileStat(
          label: 'Followers',
          value: '3.4K',
          icon: Icons.favorite_rounded,
          onTap: () => onAction('Followers list will open.'),
        ),
        const SizedBox(width: 7),
        MeProfileStat(
          label: 'Rooms',
          value: '12',
          icon: Icons.mic_rounded,
          onTap: () => onAction('My rooms will open.'),
        ),
        const SizedBox(width: 7),
        MeProfileStat(
          label: 'Visitors',
          value: '296',
          icon: Icons.visibility_rounded,
          onTap: () => onAction('Recent profile visitors will open.'),
        ),
      ],
    );
  }
}
