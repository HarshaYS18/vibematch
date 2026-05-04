import 'package:flutter/material.dart';

import '../room_theme.dart';

class ContributionRankingsBackendHint extends StatelessWidget {
  const ContributionRankingsBackendHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Backend later: GET /rooms/{roomId}/rankings/contributions?period=today|week',
      style: TextStyle(color: RoomColors.plum.withValues(alpha: 0.50), fontSize: 10, fontWeight: FontWeight.w700),
    );
  }
}
