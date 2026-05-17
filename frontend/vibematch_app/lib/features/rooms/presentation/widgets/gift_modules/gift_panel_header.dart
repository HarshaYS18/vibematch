import 'package:flutter/material.dart';

import '../../../data/gift_catalog_api_service.dart';
import 'gift_category_strip.dart';

class GiftPanelHeader extends StatelessWidget {
  const GiftPanelHeader({
    super.key,
    required this.categories,
    required this.selectedCategoryKey,
    required this.onCategoryChanged,
    required this.onStoreTap,
    this.onLuckyRankingsTap,
  });

  final List<GiftCatalogCategory> categories;
  final String selectedCategoryKey;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onStoreTap;
  final VoidCallback? onLuckyRankingsTap;

  @override
  Widget build(BuildContext context) {
    final showLuckyRankings = selectedCategoryKey == 'lucky' && onLuckyRankingsTap != null;

    return Row(
      children: [
        Expanded(
          child: GiftCategoryStrip(
            categories: categories,
            selectedCategoryKey: selectedCategoryKey,
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
