import 'package:flutter/material.dart';

import '../love_bonds/models/love_bond_models.dart';
import '../love_bonds/widgets/love_bond_card.dart';
import 'public_profile_shared_widgets.dart';

class PublicLoveBondsPanel extends StatelessWidget {
  const PublicLoveBondsPanel({
    super.key,
    required this.onVisitorTap,
  });

  final VoidCallback onVisitorTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: publicProfileWhitePanelDecoration(radius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Love & Bonds',
                  style: TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F1),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0xFFECE2D8)),
                ),
                child: const Text(
                  'Public view',
                  style: TextStyle(
                    color: Color(0xFF7A6B86),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          SizedBox(
            height: 156,
            child: Row(
              children: [
                for (var index = 0; index < mockLoveBondCards.length; index++) ...[
                  Expanded(
                    child: LoveBondCard(
                      bond: mockLoveBondCards[index],
                      onTap: onVisitorTap,
                    ),
                  ),
                  if (index != mockLoveBondCards.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
