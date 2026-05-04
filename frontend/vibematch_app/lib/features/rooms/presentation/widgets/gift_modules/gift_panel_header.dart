import 'package:flutter/material.dart';

import '../../live_room_models.dart';
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
        Expanded(
          child: GiftCategoryStrip(
            selectedCategory: selectedCategory,
            onChanged: onCategoryChanged,
          ),
        ),
      ],
    );
  }
}
