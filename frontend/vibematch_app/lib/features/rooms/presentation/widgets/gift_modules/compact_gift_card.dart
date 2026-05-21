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
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        scale: selected ? 1.04 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected ? Colors.white.withValues(alpha: 0.055) : Colors.transparent,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (selected)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: RoomColors.gold.withValues(alpha: 0.22),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  GiftVisual(
                    icon: gift.icon,
                    colors: gift.colors,
                    assetPath: gift.assetPath,
                    assetUrl: gift.assetUrl,
                    size: 60,
                    padding: 2,
                    square: true,
                    plain: true,
                  ),
                  if (selected)
                    Positioned(
                      right: 4,
                      top: 2,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: const BoxDecoration(
                          color: RoomColors.gold,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, color: Color(0xFF251538), size: 9),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                gift.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: selected ? 0.98 : 0.82),
                  fontSize: 10.2,
                  height: 1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isLuckyPacket)
                    isOwned
                        ? const Icon(Icons.inventory_2_rounded, color: RoomColors.aqua, size: 9.5)
                        : const GoldCoinIcon(size: 9.5),
                  if (!isLuckyPacket) const SizedBox(width: 2),
                  Text(
                    isLuckyPacket ? 'Custom' : (isOwned ? 'Owned' : '${gift.coins}'),
                    style: TextStyle(
                      color: isOwned ? RoomColors.aqua : RoomColors.gold,
                      fontSize: 8.8,
                      height: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
