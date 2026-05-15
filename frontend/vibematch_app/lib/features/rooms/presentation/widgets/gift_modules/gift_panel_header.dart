import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import 'gift_category_strip.dart';

class GiftPanelHeader extends StatelessWidget {
  const GiftPanelHeader({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onStoreTap,
    this.onLuckyRankingsTap,
  });

  final GiftCategory selectedCategory;
  final ValueChanged<GiftCategory> onCategoryChanged;
  final VoidCallback onStoreTap;
  final VoidCallback? onLuckyRankingsTap;

  @override
  Widget build(BuildContext context) {
    final showLuckyRankings = selectedCategory == GiftCategory.lucky && onLuckyRankingsTap != null;
    return Row(
      children: [
        Expanded(
          child: GiftCategoryStrip(
            selectedCategory: selectedCategory,
            onChanged: onCategoryChanged,
          ),
        ),
        if (showLuckyRankings) ...[
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onLuckyRankingsTap,
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFFFC857).withValues(alpha: 0.14),
                  border: Border.all(
                    color: const Color(0xFFFFC857).withValues(alpha: 0.32),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      size: 15,
                      color: Color(0xFFFFC857),
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Rank',
                      style: TextStyle(
                        color: Color(0xFFFFC857),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}