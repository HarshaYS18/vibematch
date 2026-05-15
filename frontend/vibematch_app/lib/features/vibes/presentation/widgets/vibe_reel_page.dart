import 'package:flutter/material.dart';

import '../../models/vibe_models.dart';
import 'vibe_media_player.dart';
import 'vibe_reel_action_rail.dart';
import 'vibe_reel_overlay_widgets.dart';

class VibeReelPage extends StatelessWidget {
  const VibeReelPage({
    super.key,
    required this.vibe,
    required this.onLike,
    required this.onComments,
    required this.onShare,
    required this.onSave,
  });

  final VibeItem vibe;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onShare;
  final VoidCallback onSave;

  String get _caption {
    final caption = vibe.caption.trim();
    final extras = <String>[];
    for (final raw in vibe.mentions) {
      final clean = raw.trim();
      if (clean.isEmpty) continue;
      final token = clean.startsWith('@') ? clean : '@$clean';
      if (!caption.toLowerCase().contains(token.toLowerCase()) && !extras.contains(token)) extras.add(token);
    }
    if (vibe.usesMentionAll && !caption.toLowerCase().contains('@all')) extras.add('@all');
    return extras.isEmpty ? caption : '$caption ${extras.join(' ')}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onDoubleTap: onLike,
          child: VibeMediaPlayer(vibe: vibe, onDoubleTap: onLike, respectFeedPause: false, autoplay: true),
        ),
        const VibeReelGradientOverlay(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: VibeReelAuthorCaption(vibe: vibe, caption: _caption)),
                const SizedBox(width: 12),
                VibeReelActionRail(vibe: vibe, onLike: onLike, onComments: onComments, onShare: onShare, onSave: onSave),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
