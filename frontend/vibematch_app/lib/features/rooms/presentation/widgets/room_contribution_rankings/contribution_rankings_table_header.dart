import 'package:flutter/material.dart';

import '../room_theme.dart';

class ContributionRankingsTableHeader extends StatelessWidget {
  const ContributionRankingsTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: RoomColors.pearl,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RoomColors.softLine),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Text('Rank', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w900)),
          ),
          Text('Contribution', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
