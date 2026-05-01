import 'package:flutter/material.dart';

import '../../models/vibe_item.dart';
import '../../models/vibe_media_type.dart';
import 'vibes_ui_helpers.dart';

class VibeCard extends StatelessWidget {
  const VibeCard({
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
    if (vibe.usesMentionAll &&
        !names.any((name) => name.toLowerCase() == 'all')) {
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
          decoration: vibePanelDecoration(radius: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: onProfileTap,
                    customBorder: const CircleBorder(),
                    child: VibesAvatarBubble(
                      text: vibe.avatarText,
                      colors: vibe.colors,
                      size: 48,
                    ),
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
                            style: const TextStyle(
                              color: Color(0xFF251538),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID ${vibe.authorId} • ${vibe.timeAgo}',
                            style: const TextStyle(
                              color: Color(0xFF8C8198),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
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
                      child: Icon(
                        Icons.more_horiz_rounded,
                        color: Color(0xFF8C8198),
                      ),
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
                  VibesInfoChip(
                    icon: Icons.remove_red_eye_rounded,
                    label: formatVibeCount(vibe.views),
                    color: const Color(0xFF6D5DF6),
                  ),
                  if (_hasMentions)
                    VibesInfoChip(
                      icon: Icons.alternate_email_rounded,
                      label: _mentionDisplayText,
                      color: vibe.usesMentionAll
                          ? const Color(0xFFC99A3B)
                          : const Color(0xFF6D5DF6),
                    ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  VibesActionPill(
                    icon: Icons.favorite_rounded,
                    label: formatVibeCount(vibe.likes),
                    color: const Color(0xFFE84C72),
                    onTap: onLikeTap,
                  ),
                  const SizedBox(width: 9),
                  VibesActionPill(
                    icon: Icons.chat_bubble_rounded,
                    label: formatVibeCount(vibe.comments),
                    color: const Color(0xFF6D5DF6),
                    onTap: onCommentTap,
                  ),
                  const Spacer(),
                  VibesActionPill(
                    icon: Icons.ios_share_rounded,
                    label: formatVibeCount(vibe.shares),
                    color: const Color(0xFF12C7B7),
                    onTap: onShareTap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
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
        gradient: LinearGradient(
          colors: vibe.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: vibe.colors.first.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -38,
            child: Container(
              height: 130,
              width: 130,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -44,
            child: Container(
              height: 130,
              width: 130,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Container(
              height: 62,
              width: 62,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: Icon(
                isVideo ? Icons.play_arrow_rounded : Icons.photo_rounded,
                color: Colors.white,
                size: isVideo ? 42 : 32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
