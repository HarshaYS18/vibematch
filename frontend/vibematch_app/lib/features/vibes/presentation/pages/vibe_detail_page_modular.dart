import 'package:flutter/material.dart';

import '../../../../core/icons/vm_icons.dart';
import '../../data/vibes_mock_data.dart';
import '../../models/vibe_models.dart';

class VibeDetailPageModular extends StatefulWidget {
  const VibeDetailPageModular({
    super.key,
    required this.vibe,
    this.onCommentAdded,
  });

  final VibeItem vibe;
  final VoidCallback? onCommentAdded;

  @override
  State<VibeDetailPageModular> createState() => _VibeDetailPageModularState();
}

class _VibeDetailPageModularState extends State<VibeDetailPageModular> {
  final TextEditingController _commentController = TextEditingController();
  final List<VibeComment> _comments = [...VibesMockData.comments];

  bool _videoPlaying = false;
  double _videoProgress = 0.0;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _toggleVideoPlayback() {
    if (widget.vibe.mediaType != VibeMediaType.video) return;
    setState(() => _videoPlaying = !_videoPlaying);
  }

  void _sendComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _comments.insert(
        0,
        VibeComment(
          name: 'Founder',
          avatarText: 'F',
          text: text,
          time: 'Just now',
        ),
      );
      _commentController.clear();
    });

    widget.onCommentAdded?.call();
  }

  @override
  Widget build(BuildContext context) {
    final vibe = widget.vibe;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Column(
          children: [
            _DetailHeader(vibe: vibe),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                children: [
                  _VibeAuthorStrip(vibe: vibe),
                  const SizedBox(height: 12),
                  _VibeContentPanel(
                    vibe: vibe,
                    videoPlaying: _videoPlaying,
                    videoProgress: _videoProgress,
                    onVideoTap: _toggleVideoPlayback,
                    onProgressChanged: (value) => setState(() => _videoProgress = value),
                  ),
                  const SizedBox(height: 12),
                  _VibeCaptionPanel(vibe: vibe),
                  const SizedBox(height: 14),
                  _CommentsHeader(count: _comments.length),
                  const SizedBox(height: 10),
                  ..._comments.map(
                    (comment) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CommentCard(comment: comment),
                    ),
                  ),
                ],
              ),
            ),
            _CommentComposer(
              controller: _commentController,
              onSend: _sendComment,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.vibe});

  final VibeItem vibe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFECE2D8))),
      ),
      child: Row(
        children: [
          _RoundIconButton(
            icon: VMIcons.back,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vibe Detail',
                  style: TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${vibe.mediaType.label} · ${vibe.views} views',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF7B6A86),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Icon(vibe.mediaType.icon, color: vibe.colors.first, size: 23),
        ],
      ),
    );
  }
}

class _VibeAuthorStrip extends StatelessWidget {
  const _VibeAuthorStrip({required this.vibe});

  final VibeItem vibe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _whitePanelDecoration(radius: 24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: vibe.colors.first,
            child: Text(
              vibe.avatarText,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vibe.authorName,
                  style: const TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'ID ${vibe.authorId} · ${vibe.timeAgo}',
                  style: const TextStyle(
                    color: Color(0xFF7B6A86),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: vibe.colors.first.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              vibe.tag,
              style: TextStyle(
                color: vibe.colors.first,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VibeContentPanel extends StatelessWidget {
  const _VibeContentPanel({
    required this.vibe,
    required this.videoPlaying,
    required this.videoProgress,
    required this.onVideoTap,
    required this.onProgressChanged,
  });

  final VibeItem vibe;
  final bool videoPlaying;
  final double videoProgress;
  final VoidCallback onVideoTap;
  final ValueChanged<double> onProgressChanged;

  @override
  Widget build(BuildContext context) {
    switch (vibe.mediaType) {
      case VibeMediaType.video:
        return _MockVideoPlayer(
          vibe: vibe,
          playing: videoPlaying,
          progress: videoProgress,
          onTap: onVideoTap,
          onProgressChanged: onProgressChanged,
        );
      case VibeMediaType.photo:
        return _MockPhotoViewer(vibe: vibe);
      case VibeMediaType.text:
        return _TextVibeViewer(vibe: vibe);
    }
  }
}

class _MockVideoPlayer extends StatelessWidget {
  const _MockVideoPlayer({
    required this.vibe,
    required this.playing,
    required this.progress,
    required this.onTap,
    required this.onProgressChanged,
  });

  final VibeItem vibe;
  final bool playing;
  final double progress;
  final VoidCallback onTap;
  final ValueChanged<double> onProgressChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _gradientPanelDecoration(vibe.colors),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 310,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: vibe.colors,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: playing ? 74 : 88,
                        height: playing ? 74 : 88,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: playing ? 0.20 : 0.34),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
                        ),
                        child: Icon(
                          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: playing ? 42 : 52,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Row(
                      children: [
                        Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            playing ? 'Playing mock video' : 'Tap video to play',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          '${(progress * 60).round()}s / 60s',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.84), fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            color: Colors.black.withValues(alpha: 0.18),
            child: Slider(
              value: progress,
              onChanged: onProgressChanged,
              min: 0,
              max: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MockPhotoViewer extends StatelessWidget {
  const _MockPhotoViewer({required this.vibe});

  final VibeItem vibe;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 330,
      decoration: _gradientPanelDecoration(vibe.colors),
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Icon(
                Icons.photo_rounded,
                color: Colors.white.withValues(alpha: 0.88),
                size: 92,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Text(
              'Photo Vibe preview',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextVibeViewer extends StatelessWidget {
  const _TextVibeViewer({required this.vibe});

  final VibeItem vibe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _gradientPanelDecoration(vibe.colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote_rounded, color: Colors.white.withValues(alpha: 0.80), size: 44),
          const SizedBox(height: 16),
          Text(
            vibe.caption,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              height: 1.28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _VibeCaptionPanel extends StatelessWidget {
  const _VibeCaptionPanel({required this.vibe});

  final VibeItem vibe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _whitePanelDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (vibe.mediaType != VibeMediaType.text) ...[
            _MentionRichText(
              text: vibe.caption,
              baseStyle: const TextStyle(color: Color(0xFF251538), fontSize: 14, height: 1.35, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              _Metric(icon: Icons.favorite_rounded, label: '${vibe.likes}'),
              const SizedBox(width: 12),
              _Metric(icon: Icons.mode_comment_rounded, label: '${vibe.comments}'),
              const SizedBox(width: 12),
              _Metric(icon: Icons.share_rounded, label: '${vibe.shares}'),
              const Spacer(),
              Text(
                '${vibe.views} views',
                style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentsHeader extends StatelessWidget {
  const _CommentsHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Comments',
            style: TextStyle(color: Color(0xFF251538), fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ),
        Text(
          '$count total',
          style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment});

  final VibeComment comment;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF8C5CF6),
          child: Text(comment.avatarText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: _whitePanelDecoration(radius: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment.name, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                _MentionRichText(
                  text: comment.text,
                  baseStyle: const TextStyle(color: Color(0xFF5E526B), height: 1.3, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(comment.time, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 10.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFECE2D8))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Comment with @name or @all...',
                hintStyle: const TextStyle(color: Color(0xFF8C8198), fontWeight: FontWeight.w700),
                filled: true,
                fillColor: const Color(0xFFFAF7F1),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF12C7B7))),
              ),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onSend,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF251538),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(VMIcons.send, color: Colors.white),
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
      children: [
        Icon(icon, color: const Color(0xFF8C5CF6), size: 17),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Color(0xFF4A2A63), fontSize: 12, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _MentionRichText extends StatelessWidget {
  const _MentionRichText({required this.text, required this.baseStyle});

  final String text;
  final TextStyle baseStyle;

  static final RegExp _mentionPattern = RegExp(r'@[A-Za-z0-9_]+');

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    var currentIndex = 0;

    for (final match in _mentionPattern.allMatches(text)) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(text: text.substring(currentIndex, match.start)));
      }

      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: const TextStyle(color: Color(0xFF6D5DF6), fontWeight: FontWeight.w900),
        ),
      );
      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }

    return RichText(text: TextSpan(style: baseStyle, children: spans));
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: Icon(icon, color: const Color(0xFF251538)),
      ),
    );
  }
}

BoxDecoration _whitePanelDecoration({required double radius}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFECE2D8)),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF251538).withValues(alpha: 0.035),
        blurRadius: 14,
        offset: const Offset(0, 7),
      ),
    ],
  );
}

BoxDecoration _gradientPanelDecoration(List<Color> colors) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(28),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    ),
    boxShadow: [
      BoxShadow(
        color: colors.first.withValues(alpha: 0.20),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );
}
