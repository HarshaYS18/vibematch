import 'package:flutter/material.dart';

import '../../models/vibe_models.dart';

class VibeReelActionRail extends StatelessWidget {
  const VibeReelActionRail({
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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RailButton(
          icon: vibe.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: vibe.likedByMe ? const Color(0xFFE84C72) : Colors.white,
          label: _formatCount(vibe.likes),
          onTap: onLike,
        ),
        _RailButton(icon: Icons.mode_comment_rounded, label: _formatCount(vibe.comments), onTap: onComments),
        _RailButton(icon: Icons.send_rounded, label: _formatCount(vibe.shares), onTap: onShare),
        _RailButton(
          icon: vibe.savedByMe ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          label: _formatCount(vibe.saves),
          onTap: onSave,
        ),
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.icon, required this.label, required this.onTap, this.color = Colors.white});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Column(
          children: [
            Icon(icon, color: color, size: 31),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

String _formatCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  return '$value';
}
