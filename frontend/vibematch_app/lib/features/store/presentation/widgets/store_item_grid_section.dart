import 'package:flutter/material.dart';

import '../../models/store_models.dart';

class StoreItemGridSection extends StatelessWidget {
  const StoreItemGridSection({
    super.key,
    required this.items,
    required this.onPurchase,
  });

  final List<StoreItem> items;
  final ValueChanged<StoreItem> onPurchase;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            'No items in this section yet',
            style: TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      sliver: SliverGrid.builder(
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemBuilder: (context, index) => _StoreItemCard(
          item: items[index],
          onPurchase: () => onPurchase(items[index]),
        ),
      ),
    );
  }
}

class _StoreItemCard extends StatelessWidget {
  const _StoreItemCard({required this.item, required this.onPurchase});

  final StoreItem item;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final buttonText = item.isOwned ? 'Owned' : item.isFree ? 'Claim' : '${compactCoins(item.priceCoins)} coins';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEDE3D7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF251538), Color(0xFF6D5DF6)]),
                  ),
                ),
                if (item.imageUrl != null)
                  Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  )
                else if (item.assetPath != null)
                  Image.asset(
                    item.assetPath!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  )
                else
                  const Center(child: Icon(Icons.storefront_rounded, color: Colors.white, size: 42)),
                if (item.isFeatured)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFFFC857), borderRadius: BorderRadius.circular(999)),
                      child: const Text('HOT', style: TextStyle(color: Color(0xFF251538), fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description ?? storeCategoryLabel(item.category),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11, height: 1.2, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: item.isOwned ? null : onPurchase,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF251538),
                      disabledBackgroundColor: const Color(0xFFEDE3D7),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: const Color(0xFF7B6A86),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                    child: Text(buttonText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
