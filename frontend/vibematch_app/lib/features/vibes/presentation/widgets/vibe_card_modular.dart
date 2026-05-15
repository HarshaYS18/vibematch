import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../auth/data/auth_api_service.dart';
import '../../models/vibe_models.dart';

class VibeCardModular extends StatefulWidget {
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

  @override
  State<VibeCardModular> createState() => _VibeCardModularState();
}

class _VibeCardModularState extends State<VibeCardModular> {
  static final ValueNotifier<String?> _openActionPillKey = ValueNotifier<String?>(null);

  String get _pillKey => widget.vibe.id.trim().isNotEmpty ? widget.vibe.id : '${widget.vibe.authorId}-${widget.vibe.caption.hashCode}';

  bool get _isSelfVibe {
    final publicId = const AuthApiService().cachedUser?.publicUserId.toString();
    return publicId != null && publicId == widget.vibe.authorId;
  }

  String get _caption {
    final caption = widget.vibe.caption.trim();
    final extras = <String>[];
    for (final raw in widget.vibe.mentions) {
      final clean = raw.trim();
      if (clean.isEmpty) continue;
      final token = clean.startsWith('@') ? clean : '@$clean';
      if (!caption.toLowerCase().contains(token.toLowerCase()) && !extras.contains(token)) extras.add(token);
    }
    if (widget.vibe.usesMentionAll && !caption.toLowerCase().contains('@all')) extras.add('@all');
    return extras.isEmpty ? caption : '$caption ${extras.join(' ')}';
  }

  void _toggleActionPill() {
    _openActionPillKey.value = _openActionPillKey.value == _pillKey ? null : _pillKey;
  }

  void _hideActionPill() {
    if (_openActionPillKey.value == _pillKey) _openActionPillKey.value = null;
  }

  void _runAction() {
    _hideActionPill();
    widget.onMoreTap();
  }

  void _handleDoubleTap() {
    _hideActionPill();
    widget.onLikeTap();
  }

  void _handleOutsideTap() {
    _hideActionPill();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context).width;
    final isTextVibe = widget.vibe.mediaType == VibeMediaType.text;

    return ValueListenableBuilder<String?>(
      valueListenable: _openActionPillKey,
      builder: (context, openKey, _) {
        final showActionPill = openKey == _pillKey;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _handleOutsideTap,
              onDoubleTap: _handleDoubleTap,
              child: ColoredBox(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AuthorRow(vibe: widget.vibe, onProfileTap: widget.onProfileTap, onMoreTap: _toggleActionPill),
                    if (!isTextVibe)
                      SizedBox(
                        width: size,
                        height: size,
                        child: ClipRect(child: VibeMediaPlayer(vibe: widget.vibe, onDoubleTap: _handleDoubleTap)),
                      ),
                    _MetaPanel(
                      vibe: widget.vibe,
                      caption: _caption,
                      onLikeTap: widget.onLikeTap,
                      onCommentTap: widget.onCommentTap,
                      onShareTap: widget.onShareTap,
                      onSaveTap: widget.onSaveTap,
                      isTextVibe: isTextVibe,
                    ),
                    const Divider(height: 1, color: Color(0xFFECE2D8)),
                  ],
                ),
              ),
            ),
            if (showActionPill)
              Positioned(
                top: 46,
                right: 28,
                child: _InlineVibeActionPill(isSelfVibe: _isSelfVibe, onTap: _runAction),
              ),
          ],
        );
      },
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.vibe, required this.onProfileTap, required this.onMoreTap});
  final VibeItem vibe;
  final VoidCallback onProfileTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.white,
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(children: [
              InkWell(onTap: onProfileTap, customBorder: const CircleBorder(), child: VibeAvatar(vibe: vibe, size: 38)),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: onProfileTap,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(vibe.authorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF111015), fontSize: 14, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(vibe.timeAgo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              IconButton(onPressed: onMoreTap, icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF111015))),
            ]),
          ),
        ),
      );
}

class _InlineVibeActionPill extends StatelessWidget {
  const _InlineVibeActionPill({required this.isSelfVibe, required this.onTap});

  final bool isSelfVibe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelfVibe ? const Color(0xFFE84C72) : const Color(0xFFC99A3B);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFECE2D8)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 20, offset: const Offset(0, 9))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isSelfVibe ? Icons.delete_outline_rounded : Icons.report_gmailerrorred_rounded, color: color, size: 19),
              const SizedBox(width: 8),
              Text(isSelfVibe ? 'Delete Vibe' : 'Report Vibe', style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPanel extends StatelessWidget {
  const _MetaPanel({required this.vibe, required this.caption, required this.onLikeTap, required this.onCommentTap, required this.onShareTap, required this.onSaveTap, required this.isTextVibe});
  final VibeItem vibe;
  final String caption;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final VoidCallback onSaveTap;
  final bool isTextVibe;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, isTextVibe ? 4 : 0, 0, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (caption.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(14, isTextVibe ? 4 : 2, 14, isTextVibe ? 10 : 2),
                child: isTextVibe
                    ? _PlainCaption(caption: caption, fontSize: 16, lineHeight: 1.35)
                    : _CaptionWithAuthor(authorName: vibe.authorName, caption: caption, fontSize: 13.3, lineHeight: 1.32),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(children: [
                _IconAction(icon: vibe.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: vibe.likedByMe ? const Color(0xFFE84C72) : const Color(0xFF111015), onTap: onLikeTap),
                _IconAction(icon: Icons.mode_comment_outlined, color: const Color(0xFF111015), onTap: onCommentTap),
                _IconAction(icon: Icons.send_outlined, color: const Color(0xFF111015), onTap: onShareTap),
                const Spacer(),
                _IconAction(icon: vibe.savedByMe ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: const Color(0xFF111015), onTap: onSaveTap),
              ]),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 4), child: Text(_likesText(vibe.likes), style: const TextStyle(color: Color(0xFF111015), fontSize: 13, fontWeight: FontWeight.w900))),
            if (vibe.comments > 0) InkWell(onTap: onCommentTap, child: Padding(padding: const EdgeInsets.fromLTRB(14, 5, 14, 2), child: Text('View all ${_formatCount(vibe.comments)} comments', style: const TextStyle(color: Color(0xFF8C8198), fontSize: 13, fontWeight: FontWeight.w700)))),
            Padding(padding: const EdgeInsets.fromLTRB(14, 5, 14, 0), child: Text(vibe.timeAgo.toUpperCase(), style: const TextStyle(color: Color(0xFF8C8198), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.2))),
          ]),
        ),
      );
}

class VibeAvatar extends StatelessWidget {
  const VibeAvatar({super.key, required this.vibe, required this.size});
  final VibeItem vibe;
  final double size;
  @override
  Widget build(BuildContext context) {
    final avatarUrl = vibe.avatarUrl?.trim();
    return Container(width: size, height: size, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: vibe.colors)), child: avatarUrl != null && avatarUrl.isNotEmpty ? Image.network(avatarUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => _FallbackAvatar(vibe: vibe)) : _FallbackAvatar(vibe: vibe));
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
    if (vibe.mediaType == VibeMediaType.text) return const SizedBox.shrink();
    if (mediaUrl == null || mediaUrl.isEmpty) return GestureDetector(onDoubleTap: onDoubleTap, child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: vibe.colors)), child: Icon(vibe.mediaType == VibeMediaType.video ? Icons.play_circle_fill_rounded : Icons.photo_rounded, color: Colors.white, size: 72)));
    if (vibe.mediaType == VibeMediaType.video) return GestureDetector(onDoubleTap: onDoubleTap, child: _NetworkVideoPlayer(url: mediaUrl));
    return GestureDetector(onDoubleTap: onDoubleTap, child: Image.network(mediaUrl, width: double.infinity, height: double.infinity, fit: BoxFit.cover, loadingBuilder: (context, child, loadingProgress) => loadingProgress == null ? child : _MediaLoading(colors: vibe.colors), errorBuilder: (_, _, _) => _MediaFallback(vibe: vibe)));
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
  bool _showPlayButton = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..initialize().then((_) {
        if (mounted) setState(() => _isReady = true);
      }).catchError((_) {
        if (mounted) setState(() => _hasError = true);
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
    if (controller.value.isPlaying) {
      controller.pause();
      setState(() => _showPlayButton = true);
    } else {
      controller.play();
      setState(() => _showPlayButton = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_hasError) return const Center(child: Icon(Icons.broken_image_rounded, size: 44, color: Color(0xFF8C8198)));
    if (controller == null || !_isReady) return const Center(child: CircularProgressIndicator(color: Color(0xFF111015), strokeWidth: 2.6));
    return Stack(fit: StackFit.expand, clipBehavior: Clip.hardEdge, children: [
      Container(color: Colors.black),
      FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: controller.value.size.width, height: controller.value.size.height, child: VideoPlayer(controller))),
      Material(color: Colors.transparent, child: InkWell(onTap: _togglePlayback, child: Center(child: AnimatedOpacity(opacity: _showPlayButton ? 1 : 0, duration: const Duration(milliseconds: 140), child: Container(width: 62, height: 62, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.34), shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 44)))))),
    ]);
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

class _PlainCaption extends StatelessWidget {
  const _PlainCaption({required this.caption, this.fontSize = 16, this.lineHeight = 1.35});
  final String caption;
  final double fontSize;
  final double lineHeight;
  static final RegExp _mentionPattern = RegExp(r'@[A-Za-z0-9_]+');
  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    var index = 0;
    for (final match in _mentionPattern.allMatches(caption)) {
      if (match.start > index) spans.add(TextSpan(text: caption.substring(index, match.start)));
      spans.add(TextSpan(text: caption.substring(match.start, match.end), style: const TextStyle(color: Color(0xFF3859D6), fontWeight: FontWeight.w900)));
      index = match.end;
    }
    if (index < caption.length) spans.add(TextSpan(text: caption.substring(index)));
    return RichText(text: TextSpan(style: TextStyle(color: const Color(0xFF111015), fontSize: fontSize, height: lineHeight, fontWeight: FontWeight.w600), children: spans));
  }
}

class _CaptionWithAuthor extends StatelessWidget {
  const _CaptionWithAuthor({required this.authorName, required this.caption, this.fontSize = 13.3, this.lineHeight = 1.32});
  final String authorName;
  final String caption;
  final double fontSize;
  final double lineHeight;
  static final RegExp _mentionPattern = RegExp(r'@[A-Za-z0-9_]+');
  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[
      TextSpan(text: '$authorName  ', style: const TextStyle(color: Color(0xFF8C5CF6), fontWeight: FontWeight.w900)),
    ];
    var index = 0;
    for (final match in _mentionPattern.allMatches(caption)) {
      if (match.start > index) spans.add(TextSpan(text: caption.substring(index, match.start)));
      spans.add(TextSpan(text: caption.substring(match.start, match.end), style: const TextStyle(color: Color(0xFF3859D6), fontWeight: FontWeight.w900)));
      index = match.end;
    }
    if (index < caption.length) spans.add(TextSpan(text: caption.substring(index)));
    return RichText(text: TextSpan(style: TextStyle(color: const Color(0xFF111015), fontSize: fontSize, height: lineHeight, fontWeight: FontWeight.w600), children: spans));
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

String _likesText(int likes) {
  if (likes <= 0) return 'Be the first to like this';
  if (likes == 1) return '1 like';
  return '${_formatCount(likes)} likes';
}

String _formatCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  return '$value';
}
