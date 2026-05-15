import 'package:flutter/material.dart';

import '../../models/vibe_models.dart';
import 'vibe_avatar.dart';

class VibeReelGradientOverlay extends StatelessWidget {
  const VibeReelGradientOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.20),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.78),
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
      ),
    );
  }
}

class VibeReelAuthorCaption extends StatelessWidget {
  const VibeReelAuthorCaption({super.key, required this.vibe, required this.caption});

  final VibeItem vibe;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            VibeAvatar(vibe: vibe, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                vibe.authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              vibe.timeAgo,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.76), fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            caption,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13.4, height: 1.35, fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }
}
