import 'package:flutter/material.dart';

import 'love_bonds_background.dart';

class LoveBondLevelPanel extends StatelessWidget {
  const LoveBondLevelPanel({
    super.key,
    required this.onRewardsTap,
  });

  final VoidCallback onRewardsTap;

  @override
  Widget build(BuildContext context) {
    return LoveBondsGlassPanel(
      padding: const EdgeInsets.all(16),
      radius: 28,
      child: Row(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF3C7), Color(0xFFFFB7DC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5AAA).withValues(alpha: 0.20),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.home_rounded, color: Color(0xFFFF5AAA), size: 44),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lover Lv.3',
                  style: TextStyle(
                    color: Color(0xFFE7479C),
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: 780 / 1500,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFEED2E3),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFF5AAA)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '💗 780 / 1500',
                  style: TextStyle(
                    color: Color(0xFF6D5570),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Keep gaining Affection to level up and unlock more perks!',
                  style: TextStyle(
                    color: Color(0xFF6D5570),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: onRewardsTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF5AAA), Color(0xFFFF85C6)]),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.65), width: 1.4),
              ),
              child: const Text(
                'Rewards',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
