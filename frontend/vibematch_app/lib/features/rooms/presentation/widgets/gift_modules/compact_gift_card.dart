import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import '../economy/gold_coin_icon.dart';
import '../room_theme.dart';
import 'gift_visual.dart';

class CompactGiftCard extends StatelessWidget {
  const CompactGiftCard({super.key, required this.gift, required this.selected, required this.onTap});

  final GiftItem gift;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOwned = gift.category == GiftCategory.baggage;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: selected ? 0.15 : 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? gift.colors.first : Colors.white12, width: selected ? 1.6 : 1),
          boxShadow: selected ? [BoxShadow(color: gift.colors.first.withValues(alpha: 0.20), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Column(
          children: [
            GiftVisual(icon: gift.icon, colors: gift.colors, assetPath: gift.assetPath, size: 30, padding: 2),
            const SizedBox(height: 3),
            Text(gift.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9.7, fontWeight: FontWeight.w900)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                isOwned ? const Icon(Icons.inventory_2_rounded, color: RoomColors.aqua, size: 10) : const GoldCoinIcon(size: 10),
                const SizedBox(width: 2),
                Text(isOwned ? 'Owned' : '${gift.coins}', style: TextStyle(color: isOwned ? RoomColors.aqua : RoomColors.gold, fontSize: 9.4, fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
