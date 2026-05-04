import 'package:flutter/material.dart';

import '../../models/vibe_models.dart';

class VibeCardModular extends StatelessWidget {
  const VibeCardModular({
    super.key,
    required this.vibe,
    required this.onProfileTap,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onShareTap,
    required this.onMoreTap,
  });

  final VibeItem vibe;
  final VoidCallback onProfileTap;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final VoidCallback onMoreTap;

  bool get _hasMentions => vibe.usesMentionAll || vibe.mentions.isNotEmpty;

  String get _mentionDisplayText {
    final names = <String>[...vibe.mentions];
    if (vibe.usesMentionAll && !names.any((name) => name.toLowerCase() == 'all')) {
      names.add('all');
    }
    return names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final isTextOnly = vibe.mediaType == VibeMediaType.text;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onCommentTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFECE2D8)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF251538).withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: onProfileTap,
                    customBorder: const CircleBorder(),
                    child: _AvatarBubble(text: vibe.avatarText, colors: vibe.colors, size: 48),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: InkWell(
                      onTap: onProfileTap,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vibe.authorName,
                            style: const TextStyle(color: Color(0xFF251538), fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID ${vibe.authorId} • ${vibe.timeAgo}',
                            style: const TextStyle(color: Color(0xFF8C8198), fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _VibeTag(label: vibe.tag, color: vibe.colors.first),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: onMoreTap,
                    borderRadius: BorderRadius.circular(99),
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(Icons.more_horiz_rounded, color: Color(0xFF8C8198)),
                    ),
                  ),
                ],
              ),
              if (!isTextOnly) ...[
                const SizedBox(height: 13),
                _VibeMediaPreview(vibe: vibe),
                const SizedBox(height: 13),
              ] else
                const SizedBox(height: 12),
              Text(
                vibe.caption,
                style: TextStyle(
                  color: const Color(0xFF5E526B),
                  fontSize: isTextOnly ? 14 : 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(icon: Icons.remove_red_eye_rounded, label: _formatCount(vibe.views), color: const Color(0xFF6D5DF6)),
                  if (_hasMentions)
                    _InfoChip(
                      icon: Icons.alternate_email_rounded,
                      label: _mentionDisplayText,
                      color: vibe.usesMentionAll ? const Color(0xFFC99A3B) : const Color(0xFF6D5DF6),
                    ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  _ActionPill(
                    icon: vibe.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    label: _formatCount(vibe.likes),
                    color: const Color(0xFFE84C72),
                    onTap: onLikeTap,
                  ),
                  const SizedBox(width: 9),
                  _ActionPill(icon: Icons.chat_bubble_rounded, label: _formatCount(vibe.comments), color: const Color(0xFF6D5DF6), onTap: onCommentTap),
                  const Spacer(),
                  _ActionPill(icon: Icons.ios_share_rounded, label: _formatCount(vibe.shares), color: const Color(0xFF12C7B7), onTap: onShareTap),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VibeMediaPreview extends StatelessWidget {
  const _VibeMediaPreview({required this.vibe});
  final VibeItem vibe;
  @override
  Widget build(BuildContext context) {
    final isVideo = vibe.mediaType == VibeMediaType.video;
    return Container(
      height: 190,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: vibe.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: vibe.colors.first.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 9))],
      ),
      child: Center(
        child: Container(
          height: 62,
          width: 62,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
          child: Icon(isVideo ? Icons.play_arrow_rounded : Icons.photo_rounded, color: Colors.white, size: isVideo ? 42 : 32),
        ),
      ),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({required this.text, required this.colors, required this.size});
  final String text;
  final List<Color> colors;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: colors)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
    );
  }
}

class _VibeTag extends StatelessWidget {
  const _VibeTag({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: color), const SizedBox(width: 5), Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w900))]),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 17, color: color), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900))]),
      ),
    );
  }
}

String _formatCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  return '$value';
}
