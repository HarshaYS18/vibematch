import 'package:flutter/material.dart';

import '../../../auth/data/auth_api_service.dart';
import '../../models/vibe_models.dart';
import 'vibe_avatar.dart';
import 'vibe_media_playback_gate.dart';
import 'vibe_media_player.dart';

/// Feed card presentation for one Vibe.
///
/// The open action-pill key is supplied by the owning feed page so cards can
/// coordinate a single visible pill without process-global mutable state. The
/// notifier is presentation-only and must be disposed by the page that owns it.
class VibeCardModular extends StatefulWidget {
  const VibeCardModular({
    super.key,
    required this.vibe,
    required this.playbackGate,
    required this.actionPillKey,
    required this.onProfileTap,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onShareTap,
    required this.onSaveTap,
    required this.onMoreTap,
  });

  final VibeItem vibe;
  final VibeMediaPlaybackGate playbackGate;
  final ValueNotifier<String?> actionPillKey;
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
    widget.actionPillKey.value = widget.actionPillKey.value == _pillKey ? null : _pillKey;
  }

  void _hideActionPill() {
    if (widget.actionPillKey.value == _pillKey) widget.actionPillKey.value = null;
  }

  void _runAction() {
    _hideActionPill();
    widget.onMoreTap();
  }

  void _handleDoubleTap() {
    _hideActionPill();
    widget.onLikeTap();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mediaHeight = (width * 1.04).clamp(330.0, 470.0).toDouble();
    final isTextVibe = widget.vibe.mediaType == VibeMediaType.text;

    return ValueListenableBuilder<String?>(
      valueListenable: widget.actionPillKey,
      builder: (context, openKey, _) {
        final showActionPill = openKey == _pillKey;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hideActionPill,
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
                        width: width,
                        height: mediaHeight,
                        child: RepaintBoundary(child: ClipRect(child: VibeMediaPlayer(vibe: widget.vibe, onDoubleTap: _handleDoubleTap, playbackGate: widget.playbackGate))),
                      ),
                    _MetaPanel(
                      vibe: widget.vibe,
                      caption: _caption,
                      isTextVibe: isTextVibe,
                      onLikeTap: widget.onLikeTap,
                      onCommentTap: widget.onCommentTap,
                      onShareTap: widget.onShareTap,
                      onSaveTap: widget.onSaveTap,
                    ),
                    const Divider(height: 1, color: Color(0xFFECE2D8)),
                  ],
                ),
              ),
            ),
            if (showActionPill)
              Positioned(top: 42, right: 22, child: _InlineVibeActionPill(isSelfVibe: _isSelfVibe, onTap: _runAction)),
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
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          child: Row(
            children: [
              InkWell(onTap: onProfileTap, customBorder: const CircleBorder(), child: VibeAvatar(vibe: vibe, size: 34)),
              const SizedBox(width: 9),
              Expanded(
                child: InkWell(
                  onTap: onProfileTap,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vibe.authorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF111015), fontSize: 12.8, fontWeight: FontWeight.w800, height: 1)),
                      const SizedBox(height: 3),
                      Text(vibe.timeAgo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 10.2, fontWeight: FontWeight.w600, height: 1)),
                    ],
                  ),
                ),
              ),
              IconButton(onPressed: onMoreTap, icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF111015), size: 20)),
            ],
          ),
        ),
      ),
    );
  }
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFECE2D8)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 16, offset: const Offset(0, 7))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(isSelfVibe ? Icons.delete_outline_rounded : Icons.report_gmailerrorred_rounded, color: color, size: 17), const SizedBox(width: 7), Text(isSelfVibe ? 'Delete' : 'Report', style: TextStyle(color: color, fontSize: 11.2, fontWeight: FontWeight.w800))]),
        ),
      ),
    );
  }
}

class _MetaPanel extends StatelessWidget {
  const _MetaPanel({required this.vibe, required this.caption, required this.isTextVibe, required this.onLikeTap, required this.onCommentTap, required this.onShareTap, required this.onSaveTap});

  final VibeItem vibe;
  final String caption;
  final bool isTextVibe;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final VoidCallback onSaveTap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, isTextVibe ? 4 : 0, 0, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 3, 6, 0),
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
            Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 3), child: Text(_likesText(vibe.likes), style: const TextStyle(color: Color(0xFF111015), fontSize: 11.5, fontWeight: FontWeight.w800, height: 1.05))),
            if (caption.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(12, isTextVibe ? 5 : 2, 12, 2),
                child: isTextVibe ? _PlainCaption(caption: caption, fontSize: 14, lineHeight: 1.25) : _CaptionWithAuthor(authorName: vibe.authorName, caption: caption, fontSize: 12.1, lineHeight: 1.25),
              ),
            if (vibe.comments > 0)
              InkWell(onTap: onCommentTap, child: Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 1), child: Text('View all ${_formatCount(vibe.comments)} comments', style: const TextStyle(color: Color(0xFF8C8198), fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.05)))),
            Padding(padding: const EdgeInsets.fromLTRB(12, 5, 12, 0), child: Text(vibe.timeAgo.toUpperCase(), style: const TextStyle(color: Color(0xFF8C8198), fontSize: 9.2, fontWeight: FontWeight.w700, letterSpacing: 0.2, height: 1))),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(onPressed: onTap, icon: Icon(icon, color: color, size: 22));
}

class _PlainCaption extends StatelessWidget {
  const _PlainCaption({required this.caption, this.fontSize = 14, this.lineHeight = 1.25});

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
      spans.add(TextSpan(text: caption.substring(match.start, match.end), style: const TextStyle(color: Color(0xFF3859D6), fontWeight: FontWeight.w800)));
      index = match.end;
    }
    if (index < caption.length) spans.add(TextSpan(text: caption.substring(index)));
    return RichText(text: TextSpan(style: TextStyle(color: const Color(0xFF111015), fontSize: fontSize, height: lineHeight, fontWeight: FontWeight.w500), children: spans));
  }
}

class _CaptionWithAuthor extends StatelessWidget {
  const _CaptionWithAuthor({required this.authorName, required this.caption, this.fontSize = 12.1, this.lineHeight = 1.25});

  final String authorName;
  final String caption;
  final double fontSize;
  final double lineHeight;

  static final RegExp _mentionPattern = RegExp(r'@[A-Za-z0-9_]+');

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[TextSpan(text: '$authorName  ', style: const TextStyle(color: Color(0xFF8C5CF6), fontWeight: FontWeight.w800))];
    var index = 0;
    for (final match in _mentionPattern.allMatches(caption)) {
      if (match.start > index) spans.add(TextSpan(text: caption.substring(index, match.start)));
      spans.add(TextSpan(text: caption.substring(match.start, match.end), style: const TextStyle(color: Color(0xFF3859D6), fontWeight: FontWeight.w800)));
      index = match.end;
    }
    if (index < caption.length) spans.add(TextSpan(text: caption.substring(index)));
    return RichText(text: TextSpan(style: TextStyle(color: const Color(0xFF111015), fontSize: fontSize, height: lineHeight, fontWeight: FontWeight.w500), children: spans));
  }
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
