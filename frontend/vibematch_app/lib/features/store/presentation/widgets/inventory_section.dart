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
        separatorBuilder: (context, index) => const SizedBox(height: 10),
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
    final validity = item.isTimed ? '${item.durationDays} days validity' : 'Permanent validity';
    final remaining = expiryLabel(item.expiresAt);

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
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(colors: [Color(0xFF251538), Color(0xFF12C7B7)]),
                ),
                clipBehavior: Clip.antiAlias,
                child: item.imageUrl != null
                    ? Image.network(
                        item.imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.inventory_2_rounded, color: Colors.white),
                      )
                    : item.assetPath != null
                        ? Image.asset(
                            item.assetPath!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.inventory_2_rounded, color: Colors.white),
                          )
                        : const Icon(Icons.inventory_2_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(storeCategoryLabel(item.category), style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        _MiniChip(icon: Icons.event_available_rounded, label: validity),
                        _MiniChip(icon: Icons.hourglass_bottom_rounded, label: remaining),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFEDE3D7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF7B6A86)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Color(0xFF251538), fontSize: 10.5, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
