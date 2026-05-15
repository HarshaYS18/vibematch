import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/vibe_models.dart';

class VibeCardModular extends StatelessWidget {
  const VibeCardModular({
    super.key,
    required this.vibe,
    required this.onProfileTap,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onShareTap,
    required this.onSaveTap,
    required this.onMoreTap,
  });

  final VibeItem vibe;
  final VoidCallback onProfileTap;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final VoidCallback onSaveTap;
  final VoidCallback onMoreTap;

  String get _captionWithInlineMentions {
    final caption = vibe.caption.trim();
    final mentionTokens = <String>[];
    for (final rawMention in vibe.mentions) {
      final mention = rawMention.trim();
      if (mention.isEmpty) continue;
      final token = mention.startsWith('@') ? mention : '@$mention';
      if (!caption.toLowerCase().contains(token.toLowerCase()) && !mentionTokens.any((item) => item.toLowerCase() == token.toLowerCase())) {
        mentionTokens.add(token);
      }
    }
    if (vibe.usesMentionAll && !caption.toLowerCase().contains('@all')) mentionTokens.add('@all');
    if (mentionTokens.isEmpty) return caption;
    return '$caption ${mentionTokens.join(' ')}';
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context).width;
    return ColoredBox(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _VibeAuthorRow(vibe: vibe, onProfileTap: onProfileTap, onMoreTap: onMoreTap),
          SizedBox(
            width: mediaSize,
            height: mediaSize,
            child: ClipRect(
              child: ColoredBox(
                color: const Color(0xFFF3F0EE),
                child: VibeMediaPlayer(vibe: vibe, onDoubleTap: onLikeTap),
              ),
            ),
          ),
          _VibePostMetaPanel(
            vibe: vibe,
            caption: _captionWithInlineMentions,
            likesText: _likesText(vibe.likes),
            onLikeTap: onLikeTap,
            onCommentTap: onCommentTap,
            onShareTap: onShareTap,
            onSaveTap: onSaveTap,
          ),
          const Divider(height: 1, color: Color(0xFFECE2D8)),
        ],
      ),
    );
  }

  String _likesText(int likes) {
    if (likes <= 0) return 'Be the first to like this';
    if (likes == 1) return '1 like';
    return '${_formatCount(likes)} likes';
  }
}

class _VibeAuthorRow extends StatelessWidget {
  const _VibeAuthorRow({required this.vibe, required this.onProfileTap, required this.onMoreTap});

  final VibeItem vibe;
  final VoidCallback onProfileTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            children: [
              InkWell(onTap: onProfileTap, customBorder: const CircleBorder(), child: VibeAvatar(vibe: vibe, size: 38)),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: onProfileTap,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vibe.authorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF111015), fontSize: 14, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(vibe.timeAgo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              IconButton(onPressed: onMoreTap, icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF111015))),
            ],
          ),
        ),
      ),
    );
  }
}

class _VibePostMetaPanel extends StatelessWidget {
  const _VibePostMetaPanel({required this.vibe, required this.caption, required this.likesText, required this.onLikeTap, required this.onCommentTap, required this.onShareTap, required this.onSaveTap});

  final VibeItem vibe;
  final String caption;
  final String likesText;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final VoidCallback onSaveTap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  _IconAction(icon: vibe.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: vibe.likedByMe ? const Color(0xFFE84C72) : const Color(0xFF111015), onTap: onLikeTap),
                  _IconAction(icon: Icons.mode_comment_outlined, color: const Color(0xFF111015), onTap: onCommentTap),
                  _IconAction(icon: Icons.send_outlined, color: const Color(0xFF111015), onTap: onShareTap),
                  const Spacer(),
                  _IconAction(icon: vibe.savedByMe ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: const Color(0xFF111015), onTap: onSaveTap),
                ],
              ),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 4), child: Text(likesText, style: const TextStyle(color: Color(0xFF111015), fontSize: 13, fontWeight: FontWeight.w900))),
            if (caption.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(14, 2, 14, 2), child: _MentionCaption(authorName: vibe.authorName, caption: caption)),
            if (vibe.comments > 0)
              InkWell(onTap: onCommentTap, child: Padding(padding: const EdgeInsets.fromLTRB(14, 5, 14, 2), child: Text('View all ${_formatCount(vibe.comments)} comments', style: const TextStyle(color: Color(0xFF8C8198), fontSize: 13, fontWeight: FontWeight.w700)))),
            Padding(padding: const EdgeInsets.fromLTRB(14, 5, 14, 0), child: Text(vibe.timeAgo.toUpperCase(), style: const TextStyle(color: Color(0xFF8C8198), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.2))),
          ],
        ),
      ),
    );
  }
}

class VibeAvatar extends StatelessWidget {
  const VibeAvatar({super.key, required this.vibe, required this.size});
  final VibeItem vibe;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = vibe.avatarUrl?.trim();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: vibe.colors)),
      child: avatarUrl != null && avatarUrl.isNotEmpty ? Image.network(avatarUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => _FallbackAvatar(vibe: vibe)) : _FallbackAvatar(vibe: vibe),
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.vibe});
  final VibeItem vibe;
  @override
  Widget build(BuildContext context) => Center(child: Text(vibe.avatarText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)));
}

class VibeMediaPlayer extends StatelessWidget {
  const VibeMediaPlayer({super.key, required this.vibe, required this.onDoubleTap});
  final VibeItem vibe;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final mediaUrl = vibe.mediaUrl?.trim();
    if (vibe.mediaType == VibeMediaType.text) {
      return GestureDetector(
        onDoubleTap: onDoubleTap,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(gradient: LinearGradient(colors: vibe.colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Center(child: Text(vibe.caption, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, height: 1.25, fontWeight: FontWeight.w900))),
        ),
      );
    }
    if (mediaUrl == null || mediaUrl.isEmpty) {
      return GestureDetector(
        onDoubleTap: onDoubleTap,
        child: Container(
          decoration: BoxDecoration(gradient: LinearGradient(colors: vibe.colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Icon(vibe.mediaType == VibeMediaType.video ? Icons.play_circle_fill_rounded : Icons.photo_rounded, color: Colors.white, size: 72),
        ),
      );
    }
    if (vibe.mediaType == VibeMediaType.video) return GestureDetector(onDoubleTap: onDoubleTap, child: _NetworkVideoPlayer(url: mediaUrl));
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Image.network(mediaUrl, width: double.infinity, height: double.infinity, fit: BoxFit.cover, loadingBuilder: (context, child, loadingProgress) => loadingProgress == null ? child : _MediaLoading(colors: vibe.colors), errorBuilder: (_, _, _) => _MediaFallback(vibe: vibe)),
    );
  }
}

class _NetworkVideoPlayer extends StatefulWidget {
  const _NetworkVideoPlayer({required this.url});
  final String url;
  @override
  State<_NetworkVideoPlayer> createState() => _NetworkVideoPlayerState();
}

class _NetworkVideoPlayerState extends State<_NetworkVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isReady = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _isReady = true);
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _hasError = true);
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !_isReady) return;
    setState(() => controller.value.isPlaying ? controller.pause() : controller.play());
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_hasError) return const Center(child: Icon(Icons.broken_image_rounded, size: 44, color: Color(0xFF8C8198)));
    if (controller == null || !_isReady) return const Center(child: CircularProgressIndicator(color: Color(0xFF111015), strokeWidth: 2.6));
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Container(color: Colors.black),
        FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(width: controller.value.size.width, height: controller.value.size.height, child: VideoPlayer(controller)),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _togglePlayback,
            child: Center(
              child: AnimatedOpacity(
                opacity: controller.value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                child: Container(width: 62, height: 62, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.34), shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 44)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(onPressed: onTap, icon: Icon(icon, color: color, size: 27));
}

class _MentionCaption extends StatelessWidget {
  const _MentionCaption({required this.authorName, required this.caption});
  final String authorName;
  final String caption;
  static final RegExp _mentionPattern = RegExp(r'@[A-Za-z0-9_]+');

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[TextSpan(text: '$authorName ', style: const TextStyle(color: Color(0xFF111015), fontWeight: FontWeight.w900))];
    var currentIndex = 0;
    for (final match in _mentionPattern.allMatches(caption)) {
      if (match.start > currentIndex) spans.add(TextSpan(text: caption.substring(currentIndex, match.start)));
      spans.add(TextSpan(text: caption.substring(match.start, match.end), style: const TextStyle(color: Color(0xFF3859D6), fontWeight: FontWeight.w900)));
      currentIndex = match.end;
    }
    if (currentIndex < caption.length) spans.add(TextSpan(text: caption.substring(currentIndex)));
    return RichText(text: TextSpan(style: const TextStyle(color: Color(0xFF111015), fontSize: 13.3, height: 1.32, fontWeight: FontWeight.w600), children: spans));
  }
}

class _MediaLoading extends StatelessWidget {
  const _MediaLoading({required this.colors});
  final List<Color> colors;
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(gradient: LinearGradient(colors: colors)), child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6)));
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback({required this.vibe});
  final VibeItem vibe;
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(gradient: LinearGradient(colors: vibe.colors)), child: Center(child: Icon(vibe.mediaType == VibeMediaType.video ? Icons.play_circle_fill_rounded : Icons.photo_rounded, color: Colors.white, size: 72)));
}

String _formatCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  return '$value';
}
