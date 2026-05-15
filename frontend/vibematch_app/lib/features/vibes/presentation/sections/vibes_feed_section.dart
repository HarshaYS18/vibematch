import 'package:flutter/material.dart';

import '../../models/vibe_models.dart';
import '../widgets/vibe_card_modular.dart';
import '../widgets/vibes_status_widgets.dart';

class VibesFeedSection extends StatelessWidget {
  const VibesFeedSection({
    super.key,
    required this.vibes,
    required this.selectedTab,
    required this.isLoading,
    required this.hasError,
    required this.onProfileTap,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onShareTap,
    required this.onSaveTap,
    required this.onMoreTap,
  });

  final List<VibeItem> vibes;
  final VibesFeedTab selectedTab;
  final bool isLoading;
  final bool hasError;
  final ValueChanged<VibeItem> onProfileTap;
  final ValueChanged<VibeItem> onLikeTap;
  final ValueChanged<VibeItem> onCommentTap;
  final ValueChanged<VibeItem> onShareTap;
  final ValueChanged<VibeItem> onSaveTap;
  final ValueChanged<VibeItem> onMoreTap;

  @override
  Widget build(BuildContext context) {
    if (vibes.isEmpty && !isLoading && !hasError) {
      return SliverFillRemaining(hasScrollBody: false, child: EmptyVibesState(selectedTab: selectedTab));
    }

    return SliverList.separated(
      itemCount: vibes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        final vibe = vibes[index];
        return VibeCardModular(
          vibe: vibe,
          onProfileTap: () => onProfileTap(vibe),
          onLikeTap: () => onLikeTap(vibe),
          onCommentTap: () => onCommentTap(vibe),
          onShareTap: () => onShareTap(vibe),
          onSaveTap: () => onSaveTap(vibe),
          onMoreTap: () => onMoreTap(vibe),
        );
      },
    );
  }
}
