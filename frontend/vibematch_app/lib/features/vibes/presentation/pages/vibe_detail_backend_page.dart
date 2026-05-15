import 'dart:async';

import 'package:flutter/material.dart';

import '../../../auth/data/auth_api_service.dart';
import '../../data/vibes_api_service.dart';
import '../../models/vibe_models.dart';
import '../widgets/vibe_card_modular.dart';

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
  bool get _canComment => widget.vibe.commentsEnabled || _isSelfVibe;

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
    if (!_canComment) {
      _toast('Comments are off for this Vibe.');
      return;
    }
    final text = _commentController.text.trim();
    if (text.isEmpty || _sendingComment) return;
    if (!_hasBackendId) {
      _toast('Refresh feed and open this Vibe again.');
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
      builder: (_) => const _ConfirmDeleteSheet(),
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

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF111015),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final vibe = widget.vibe;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111015), size: 26),
        ),
        title: const Text(
          'Vibe',
          style: TextStyle(color: Color(0xFF111015), fontSize: 18, fontWeight: FontWeight.w900),
        ),
        actions: [
          if (_isSelfVibe)
            IconButton(
              onPressed: _deleting ? null : _deleteVibe,
              icon: Icon(
                _deleting ? Icons.hourglass_top_rounded : Icons.delete_outline_rounded,
                color: const Color(0xFFE84C72),
                size: 24,
              ),
            )
          else
            IconButton(
              onPressed: () => _toast('Use feed report menu to report this Vibe.'),
              icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF111015), size: 26),
            ),
          const SizedBox(width: 6),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFECE2D8)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF111015),
                onRefresh: _loadComments,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    SliverToBoxAdapter(child: _DetailPost(vibe: vibe)),
                    if (!vibe.commentsEnabled) const SliverToBoxAdapter(child: _CommentsOffNotice()),
                    SliverToBoxAdapter(
                      child: _CommentsHeader(
                        count: _comments.length,
                        loading: _loadingComments,
                        onRefresh: _loadComments,
                      ),
                    ),
                    if (_error != null)
                      SliverToBoxAdapter(child: _ErrorCard(message: _error!, onRetry: _loadComments)),
                    if (_comments.isEmpty && !_loadingComments && _error == null)
                      const SliverToBoxAdapter(child: _EmptyCommentsState())
                    else
                      SliverList.builder(
                        itemCount: _comments.length,
                        itemBuilder: (context, index) => _CommentTile(comment: _comments[index]),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],
                ),
              ),
            ),
            _CommentComposer(
              controller: _commentController,
              sending: _sendingComment,
              enabled: _canComment,
              onSend: _sendComment,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailPost extends StatelessWidget {
  const _DetailPost({required this.vibe});
  final VibeItem vibe;

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
    final size = MediaQuery.sizeOf(context).width;
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthorRow(vibe: vibe),
          SizedBox(
            width: size,
            height: size,
            child: ClipRect(child: VibeMediaPlayer(vibe: vibe, onDoubleTap: () {})),
          ),
          _PostInfo(vibe: vibe, caption: _caption),
          const Divider(height: 1, color: Color(0xFFECE2D8)),
        ],
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.vibe});
  final VibeItem vibe;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(
          children: [
            VibeAvatar(vibe: vibe, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vibe.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF111015), fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vibe.timeAgo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF8C8198), fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostInfo extends StatelessWidget {
  const _PostInfo({required this.vibe, required this.caption});
  final VibeItem vibe;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Metric(icon: Icons.favorite_rounded, value: vibe.likes),
              const SizedBox(width: 14),
              _Metric(icon: Icons.mode_comment_rounded, value: vibe.comments),
              const SizedBox(width: 14),
              _Metric(icon: Icons.send_rounded, value: vibe.shares),
              const SizedBox(width: 14),
              _Metric(icon: Icons.bookmark_rounded, value: vibe.saves),
            ],
          ),
          const SizedBox(height: 10),
          if (caption.isNotEmpty) _Caption(authorName: vibe.authorName, caption: caption),
          const SizedBox(height: 8),
          Text(
            vibe.timeAgo.toUpperCase(),
            style: const TextStyle(color: Color(0xFF8C8198), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value});
  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF111015), size: 19),
          const SizedBox(width: 5),
          Text(
            _formatCount(value),
            style: const TextStyle(color: Color(0xFF111015), fontSize: 12.5, fontWeight: FontWeight.w900),
          ),
        ],
      );
}

class _Caption extends StatelessWidget {
  const _Caption({required this.authorName, required this.caption});
  final String authorName;
  final String caption;
  static final RegExp _mentionPattern = RegExp(r'@[A-Za-z0-9_]+');

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[
      TextSpan(text: '$authorName ', style: const TextStyle(color: Color(0xFF111015), fontWeight: FontWeight.w900)),
    ];
    var index = 0;
    for (final match in _mentionPattern.allMatches(caption)) {
      if (match.start > index) spans.add(TextSpan(text: caption.substring(index, match.start)));
      spans.add(
        TextSpan(
          text: caption.substring(match.start, match.end),
          style: const TextStyle(color: Color(0xFF3859D6), fontWeight: FontWeight.w900),
        ),
      );
      index = match.end;
    }
    if (index < caption.length) spans.add(TextSpan(text: caption.substring(index)));
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Color(0xFF111015), fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w600),
        children: spans,
      ),
    );
  }
}

class _CommentsOffNotice extends StatelessWidget {
  const _CommentsOffNotice();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF7F3EF), borderRadius: BorderRadius.circular(16)),
        child: const Row(
          children: [
            Icon(Icons.comments_disabled_rounded, color: Color(0xFF8C8198), size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Comments are off for this Vibe.',
                style: TextStyle(color: Color(0xFF8C8198), fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
}

class _CommentsHeader extends StatelessWidget {
  const _CommentsHeader({required this.count, required this.loading, required this.onRefresh});
  final int count;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
        child: Row(
          children: [
            const Expanded(
              child: Text('Comments', style: TextStyle(color: Color(0xFF111015), fontSize: 17, fontWeight: FontWeight.w900)),
            ),
            if (loading)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111015)))
            else
              Text('$count', style: const TextStyle(color: Color(0xFF8C8198), fontSize: 12.5, fontWeight: FontWeight.w900)),
            IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded, color: Color(0xFF111015), size: 20)),
          ],
        ),
      );
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});
  final VibeComment comment;

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFF111015),
              child: Text(comment.avatarText, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Color(0xFF111015), fontSize: 13.2, height: 1.32),
                      children: [
                        TextSpan(text: '${comment.name} ', style: const TextStyle(fontWeight: FontWeight.w900)),
                        TextSpan(text: comment.text, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(comment.time, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 10.5, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.sending,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final canSend = enabled && !sending;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 9, 12, 10 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFECE2D8))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: canSend,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: enabled ? 'Add a comment...' : 'Comments are off',
                hintStyle: const TextStyle(color: Color(0xFFAAA1AE), fontWeight: FontWeight.w600),
                filled: true,
                fillColor: const Color(0xFFF7F3EF),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: canSend ? onSend : null,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: enabled ? const Color(0xFF111015) : const Color(0xFFE4DFE8),
                shape: BoxShape.circle,
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(Icons.arrow_upward_rounded, color: enabled ? Colors.white : const Color(0xFF8C8198), size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCommentsState extends StatelessWidget {
  const _EmptyCommentsState();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(14, 24, 14, 28),
        child: Center(
          child: Text(
            'No comments yet. Be the first to comment.',
            style: TextStyle(color: Color(0xFF8C8198), fontWeight: FontWeight.w800),
          ),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFFF8E8), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Color(0xFFC99A3B), size: 19),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}

class _ConfirmDeleteSheet extends StatelessWidget {
  const _ConfirmDeleteSheet();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(14),
        padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Delete this Vibe?', style: TextStyle(color: Color(0xFF111015), fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text(
              'This removes the Vibe from the feed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8C8198), fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel'))),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE84C72), foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

String _formatCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  return '$value';
}
