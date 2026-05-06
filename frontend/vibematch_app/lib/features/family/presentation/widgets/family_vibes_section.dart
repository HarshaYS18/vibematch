import 'package:flutter/material.dart';

import '../../models/family_ui_models.dart';
import 'family_vibe_card.dart';

class FamilyVibesSection extends StatelessWidget {
  const FamilyVibesSection({super.key, required this.vibes});

  final List<FamilyVibeUiModel> vibes;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverList.separated(
        itemCount: vibes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, index) => FamilyVibeCard(vibe: vibes[index]),
      ),
    );
  }
}
