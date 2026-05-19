import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import '../economy/gold_coin_icon.dart';
import '../room_theme.dart';
import 'gift_visual.dart';

class CompactGiftCard extends StatelessWidget {
  const CompactGiftCard({
    super.key,
    required this.gift,
    required this.selected,
    required this.onTap,
  });

  final GiftItem gift;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOwned = gift.category == GiftCategory.baggage;
    final isLuckyPacket = gift.id == 'lucky_packet';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFC857).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.075),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFFFFD166) : Colors.white12,
            width: selected ? 1.8 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: gift.colors.first.withValues(alpha: 0.20),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            GiftVisual(
              icon: gift.icon,
              colors: gift.colors,
              assetPath: gift.assetPath,
              assetUrl: gift.assetUrl,
              size: 58,
              padding: 6,
              square: true,
            ),
            const SizedBox(height: 5),
            Text(
              gift.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isLuckyPacket)
                  isOwned
                      ? const Icon(
                          Icons.inventory_2_rounded,
                          color: RoomColors.aqua,
                          size: 10,
                        )
                      : const GoldCoinIcon(size: 10),
                if (!isLuckyPacket) const SizedBox(width: 2),
                Text(
                  isLuckyPacket
                      ? 'Custom'
                      : (isOwned ? 'Owned' : '${gift.coins}'),
                  style: TextStyle(
                    color: isOwned ? RoomColors.aqua : RoomColors.gold,
                    fontSize: isLuckyPacket ? 9.1 : 9.4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
