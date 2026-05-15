import 'package:flutter/material.dart';

import '../../models/store_models.dart';

class InventorySection extends StatelessWidget {
  const InventorySection({
    super.key,
    required this.items,
    required this.onEquip,
  });

  final List<InventoryItem> items;
  final ValueChanged<InventoryItem> onEquip;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            'No inventory items here yet',
            style: TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _InventoryCard(
          item: items[index],
          onEquip: () => onEquip(items[index]),
        ),
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.item, required this.onEquip});

  final InventoryItem item;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onEquip,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFEDE3D7)),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(colors: [Color(0xFF251538), Color(0xFF12C7B7)]),
                ),
                clipBehavior: Clip.antiAlias,
                child: item.imageUrl != null
                    ? Image.network(item.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_rounded, color: Colors.white))
                    : item.assetPath != null
                        ? Image.asset(item.assetPath!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_rounded, color: Colors.white))
                        : const Icon(Icons.inventory_2_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: const TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(storeCategoryLabel(item.category), style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(item.source, style: const TextStyle(color: Color(0xFF9A8EA4), fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: item.isEquipped ? const Color(0x3312C7B7) : const Color(0xFF251538),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.isEquipped ? 'Equipped' : 'Equip',
                  style: TextStyle(
                    color: item.isEquipped ? const Color(0xFF251538) : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
