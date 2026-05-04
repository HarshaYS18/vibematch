import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import '../room_theme.dart';
import 'gift_category_strip.dart';

class GiftPanelHeader extends StatelessWidget {
  const GiftPanelHeader({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onStoreTap,
  });

  final GiftCategory selectedCategory;
  final ValueChanged<GiftCategory> onCategoryChanged;
  final VoidCallback onStoreTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.card_giftcard_rounded, color: RoomColors.gold, size: 18),
        const SizedBox(width: 6),
        const Text('Gifts', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(width: 8),
        Expanded(
          child: GiftCategoryStrip(
            selectedCategory: selectedCategory,
            onChanged: onCategoryChanged,
          ),
        ),
        _GiftTinyIconButton(icon: Icons.apps_rounded, onTap: onStoreTap),
      ],
    );
  }
}

class _GiftTinyIconButton extends StatelessWidget {
  const _GiftTinyIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white, size: 15),
      ),
    );
  }
}
