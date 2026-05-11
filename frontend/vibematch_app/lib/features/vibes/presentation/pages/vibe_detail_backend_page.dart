import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/icons/vm_icons.dart';
import '../../../auth/data/auth_api_service.dart';
import '../../data/vibes_api_service.dart';
import '../../models/vibe_models.dart';

class VibeDetailBackendPage extends StatefulWidget {
  const VibeDetailBackendPage({
    super.key,
    required this.vibe,
    this.onCommentAdded,
    this.onDeleteVibe,
  });

  final VibeItem vibe;
  final VoidCallback? onCommentAdded;
  final Future<void> Function()? onDeleteVibe;

  @override
  State<VibeDetailBackendPage> createState() => _VibeDetailBackendPageState();
}

class _VibeDetailBackendPageState extends State<VibeDetailBackendPage> {
  final VibesApiService _api = const VibesApiService();
  final AuthApiService _authApi = const AuthApiService();
  final TextEditingController _commentController = TextEditingController();
  final List<VibeComment> _comments = <VibeComment>[];

  bool _loadingComments = false;
  bool _sendingComment = false;
  bool _deleting = false;
  String? _error;

  bool get _isSelfVibe => _authApi.cachedUser?.publicUserId.toString() == widget.vibe.authorId;
  bool get _hasBackendId => widget.vibe.id.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    unawaited(_loadComments());
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    if (!_hasBackendId || _loadingComments) return;
    setState(() {
      _loadingComments = true;
      _error = null;
    });
    try {
      final comments = await _api.loadComments(widget.vibe.id);
      if (!mounted) return;
      setState(() {
        _comments
          ..clear()
          ..addAll(comments);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sendingComment) return;
    if (!_hasBackendId) {
      _toast('This Vibe is not connected to backend. Refresh feed and open it again.');
      return;
    }
    setState(() => _sendingComment = true);
    try {
      final comment = await _api.addComment(widget.vibe.id, text);
      if (!mounted) return;
      setState(() {
        _comments.insert(0, comment);
        _commentController.clear();
      });
      widget.onCommentAdded?.call();
    } catch (error) {
      if (mounted) _toast(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _deleteVibe() async {
    if (!_isSelfVibe || _deleting) return;
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        title: 'Delete this Vibe?',
        body: 'This removes the Vibe from backend feed.',
        confirmText: 'Delete',
        confirmColor: const Color(0xFFE84C72),
      ),
    );
    if (shouldDelete != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await widget.onDeleteVibe?.call();
      if (!mounted) return;
      _toast('Vibe deleted.');
      Navigator.pop(context);
    } catch (error) {
      if (mounted) _toast(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _reportVibe() {
    _toast('Use the Vibes feed report sheet to submit a report.');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final vibe = widget.vibe;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              vibe: vibe,
              isSelfVibe: _isSelfVibe,
              deleting: _deleting,
              onBack: () => Navigator.pop(context),
              onDelete: _deleteVibe,
              onReport: _reportVibe,
            ),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF251538),
                onRefresh: _loadComments,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                  children: [
                    _AuthorCard(vibe: vibe),
                    const SizedBox(height: 12),
                    _ContentCard(vibe: vibe),
                    const SizedBox(height: 12),
                    _StatsCard(vibe: vibe),
                    const SizedBox(height: 14),
                    _CommentsHeader(
                      count: _comments.length,
                      loading: _loadingComments,
                      onRefresh: _loadComments,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      _ErrorCard(message: _error!, onRetry: _loadComments),
                    ],
                    const SizedBox(height: 10),
                    if (_comments.isEmpty && !_loadingComments)
                      const _EmptyCommentsCard()
                    else
                      ..._comments.map(
                        (comment) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CommentCard(comment: comment),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _CommentComposer(
              controller: _commentController,
              sending: _sendingComment,
              onSend: _sendComment,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.vibe, required this.isSelfVibe, required this.deleting, required this.onBack, required this.onDelete, required this.onReport});

  final VibeItem vibe;
  final bool isSelfVibe;
  final bool deleting;
  final VoidCallback onBack;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFECE2D8)))),
      child: Row(
        children: [
          _RoundIconButton(icon: VMIcons.back, onTap: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Vibe Detail', style: TextStyle(color: Color(0xFF251538), fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text('${vibe.mediaType.label} · ${vibe.views} views', style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800)),
            ]),
          ),
          _HeaderActionButton(
            icon: isSelfVibe ? Icons.delete_rounded : Icons.report_rounded,
            label: deleting ? '...' : (isSelfVibe ? 'Delete' : 'Report'),
            color: isSelfVibe ? const Color(0xFFE84C72) : const Color(0xFFC99A3B),
            onTap: deleting ? null : (isSelfVibe ? onDelete : onReport),
          ),
        ],
      ),
    );
  }
}

class _AuthorCard extends StatelessWidget {
  const _AuthorCard({required this.vibe});

  final VibeItem vibe;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Row(
        children: [
          CircleAvatar(radius: 22, backgroundColor: vibe.colors.first, child: Text(vibe.avatarText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(vibe.authorName, style: const TextStyle(color: Color(0xFF251538), fontSize: 15.5, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text('ID ${vibe.authorId} · ${vibe.timeAgo}', style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800)),
            ]),
          ),
          _Chip(text: vibe.tag, color: vibe.colors.first),
        ],
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.vibe});

  final VibeItem vibe;

  @override
  Widget build(BuildContext context) {
    final mediaUrl = vibe.mediaUrl?.trim();
    final hasUploadedMedia = mediaUrl != null && mediaUrl.isNotEmpty && vibe.mediaType != VibeMediaType.text;
    return Container(
      constraints: BoxConstraints(minHeight: vibe.mediaType == VibeMediaType.text ? 150 : 300),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: vibe.colors),
        boxShadow: [BoxShadow(color: vibe.colors.first.withValues(alpha: 0.20), blurRadius: 18, offset: const Offset(0, 9))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasUploadedMedia)
            _UploadedMediaHero(vibe: vibe, mediaUrl: mediaUrl)
          else
            Padding(
              padding: const EdgeInsets.all(22),
              child: Icon(vibe.mediaType.icon, color: Colors.white.withValues(alpha: 0.86), size: 48),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(22, hasUploadedMedia ? 16 : 0, 22, 22),
            child: Text(vibe.caption, style: const TextStyle(color: Colors.white, fontSize: 20, height: 1.28, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _UploadedMediaHero extends StatelessWidget {
  const _UploadedMediaHero({required this.vibe, required this.mediaUrl});

  final VibeItem vibe;
  final String mediaUrl;

  @override
  Widget build(BuildContext context) {
    final isVideo = vibe.mediaType == VibeMediaType.video;
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!isVideo)
            Image.network(
              mediaUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null ? child : _MediaLoading(colors: vibe.colors),
              errorBuilder: (context, error, stackTrace) => _MediaFallback(vibe: vibe),
            )
          else
            _MediaFallback(vibe: vibe),
          if (isVideo)
            Center(
              child: Container(
                height: 72,
                width: 72,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.38), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.55))),
                child: const Icon(VMIcons.play, color: Colors.white, size: 48),
              ),
            ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.42), borderRadius: BorderRadius.circular(999)),
              child: Text(isVideo ? 'Uploaded video' : 'Uploaded photo', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaLoading extends StatelessWidget {
  const _MediaLoading({required this.colors});
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(decoration: BoxDecoration(gradient: LinearGradient(colors: colors)), child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6)));
  }
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback({required this.vibe});
  final VibeItem vibe;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: vibe.colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Center(child: Icon(vibe.mediaType.icon, color: Colors.white.withValues(alpha: 0.86), size: 58)),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.vibe});

  final VibeItem vibe;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Row(
        children: [
          _Metric(icon: Icons.favorite_rounded, label: '${vibe.likes}'),
          const SizedBox(width: 12),
          _Metric(icon: Icons.mode_comment_rounded, label: '${vibe.comments}'),
          const SizedBox(width: 12),
          _Metric(icon: Icons.share_rounded, label: '${vibe.shares}'),
          const Spacer(),
          Text('${vibe.views} views', style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _CommentsHeader extends StatelessWidget {
  const _CommentsHeader({required this.count, required this.loading, required this.onRefresh});

  final int count;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Text('Comments', style: TextStyle(color: Color(0xFF251538), fontSize: 19, fontWeight: FontWeight.w900))),
        if (loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF251538))) else Text('$count total', style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w800)),
        IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded, color: Color(0xFF4A2A63), size: 19)),
      ],
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment});

  final VibeComment comment;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(radius: 18, backgroundColor: const Color(0xFF8C5CF6), child: Text(comment.avatarText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
      const SizedBox(width: 10),
      Expanded(
        child: _WhiteCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(comment.name, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(comment.text, style: const TextStyle(color: Color(0xFF5E526B), height: 1.3, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(comment.time, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 10.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ]);
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({required this.controller, required this.sending, required this.onSend});

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFECE2D8)))),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !sending,
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
          onTap: sending ? null : onSend,
          borderRadius: BorderRadius.circular(18),
          child: Container(height: 48, width: 48, decoration: BoxDecoration(color: const Color(0xFF251538), borderRadius: BorderRadius.circular(18)), child: sending ? const Padding(padding: EdgeInsets.all(13), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(VMIcons.send, color: Colors.white)),
        ),
      ]),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(999), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: color.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.20))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 17), const SizedBox(width: 5), Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w900))])));
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFECE2D8))), child: Icon(icon, color: const Color(0xFF251538))));
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE2D8)), boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.04), blurRadius: 18, offset: const Offset(0, 9))]), child: child);
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: color.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(999)), child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [Icon(icon, color: const Color(0xFF8C5CF6), size: 17), const SizedBox(width: 4), Text(label, style: const TextStyle(color: Color(0xFF4A2A63), fontSize: 12, fontWeight: FontWeight.w900))]);
}

class _EmptyCommentsCard extends StatelessWidget {
  const _EmptyCommentsCard();

  @override
  Widget build(BuildContext context) => const _WhiteCard(child: Text('No comments yet. Be the first to comment.', style: TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w800)));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE8C77C))), child: Row(children: [const Icon(Icons.wifi_off_rounded, color: Color(0xFFC99A3B), size: 19), const SizedBox(width: 9), Expanded(child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800))), TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w900)))]));
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({required this.title, required this.body, required this.confirmText, required this.confirmColor});

  final String title;
  final String body;
  final String confirmText;
  final Color confirmColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel'))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context, true), child: Text(confirmText))),
        ]),
      ]),
    );
  }
}
