import 'package:flutter/material.dart';

import '../../models/family_ui_models.dart';
import 'family_redesign_shared.dart';

class FamilyVibeCard extends StatelessWidget {
  const FamilyVibeCard({super.key, required this.vibe});

  final FamilyVibeUiModel vibe;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: FamilyRedesignDecor.panel(24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                FamilyGradientAvatar(text: vibe.avatarText, colors: vibe.gradient, size: 44),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(vibe.authorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: FamilyRedesignColors.ink, fontWeight: FontWeight.w900)),
                ),
                FamilySmallPill(icon: vibe.isVideo ? Icons.play_arrow_rounded : Icons.photo_rounded, label: vibe.tag),
              ],
            ),
          ),
          Container(
            height: 220,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: vibe.gradient)),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: FamilySoftPatternPainter())),
                Center(child: Icon(vibe.isVideo ? Icons.play_circle_fill_rounded : Icons.auto_awesome_rounded, color: Colors.white.withValues(alpha: 0.9), size: 58)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vibe.caption, style: const TextStyle(color: FamilyRedesignColors.ink, height: 1.34, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Metric(icon: Icons.favorite_border_rounded, label: '${vibe.likes}'),
                    const SizedBox(width: 16),
                    _Metric(icon: Icons.mode_comment_outlined, label: '${vibe.comments}'),
                    const SizedBox(width: 16),
                    const _Metric(icon: Icons.ios_share_rounded, label: 'Share'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: FamilyRedesignColors.ink, size: 20),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: FamilyRedesignColors.ink, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
