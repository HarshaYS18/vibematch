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
  final FocusNode _commentFocusNode = FocusNode();
  final List<VibeComment> _comments = <VibeComment>[];

  late bool _likedByMe;
  late bool _savedByMe;
  late int _likesCount;
  late int _commentsCount;
  late int _sharesCount;
  late int _savesCount;

  bool _loadingComments = false;
  bool _sendingComment = false;
  bool _deleting = false;
  String? _error;
  VibeComment? _replyingTo;

  bool get _isSelfVibe => _authApi.cachedUser?.publicUserId.toString() == widget.vibe.authorId;
  bool get _hasBackendId => widget.vibe.id.trim().isNotEmpty;
  bool get _canComment => widget.vibe.commentsEnabled || _isSelfVibe;
  bool get _isMediaVibe => widget.vibe.mediaType != VibeMediaType.text;

  @override
  void initState() {
    super.initState();
    _likedByMe = widget.vibe.likedByMe;
    _savedByMe = widget.vibe.savedByMe;
    _likesCount = widget.vibe.likes;
    _commentsCount = widget.vibe.comments;
    _sharesCount = widget.vibe.shares;
    _savesCount = widget.vibe.saves;
    unawaited(_loadComments());
  }

  @override
  void dispose() {
    _commentFocusNode.dispose();
    _commentController.dispose();
    super.dispose();
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

  void _sortComments() {
    _comments.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      if (a.isReply != b.isReply) return a.isReply ? 1 : -1;
      return 0;
    });
  }

  List<VibeComment> _orderedComments() {
    final topLevel = _comments.where((comment) => !comment.isReply).toList();
    topLevel.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return 0;
    });
    final repliesByParent = <String, List<VibeComment>>{};
    for (final reply in _comments.where((comment) => comment.isReply)) {
      final parentId = reply.parentCommentId ?? '';
      repliesByParent.putIfAbsent(parentId, () => <VibeComment>[]).add(reply);
    }
    final ordered = <VibeComment>[];
    for (final comment in topLevel) {
      ordered.add(comment);
      ordered.addAll(repliesByParent[comment.id] ?? const <VibeComment>[]);
    }
    for (final reply in _comments.where((comment) => comment.isReply && !topLevel.any((parent) => parent.id == comment.parentCommentId))) {
      ordered.add(reply);
    }
    return ordered;
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
        _sortComments();
        _commentsCount = comments.length;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _toggleVibeLike() async {
    if (!_hasBackendId) return;
    try {
      final result = await _api.toggleLike(widget.vibe.id);
      if (!mounted) return;
      setState(() {
        _likedByMe = result.likedByMe;
        _likesCount = result.likesCount;
      });
    } catch (error) {
      if (mounted) _toast(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleVibeSave() async {
    if (!_hasBackendId) return;
    try {
      final result = await _api.toggleSave(widget.vibe.id);
      if (!mounted) return;
      setState(() {
        _savedByMe = result.savedByMe;
        _savesCount = result.savesCount;
      });
      _toast(result.savedByMe ? 'Saved Vibe.' : 'Removed from saved Vibes.');
    } catch (error) {
      if (mounted) _toast(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _shareVibe() async {
    if (!_hasBackendId) return;
    try {
      final result = await _api.shareVibe(widget.vibe.id, shareChannel: 'detail');
      if (!mounted) return;
      setState(() => _sharesCount = result.sharesCount);
      _toast('Vibe shared.');
    } catch (error) {
      if (mounted) _toast(error.toString().replaceFirst('Exception: ', ''));
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
    final parentCommentId = _replyingTo?.parentCommentId ?? _replyingTo?.id;
    setState(() => _sendingComment = true);
    try {
      final comment = await _api.addComment(widget.vibe.id, text, parentCommentId: parentCommentId);
      if (!mounted) return;
      setState(() {
        _comments.add(comment);
        _sortComments();
        _commentsCount += 1;
        _commentController.clear();
        _replyingTo = null;
      });
      widget.onCommentAdded?.call();
    } catch (error) {
      if (mounted) _toast(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _toggleCommentLike(VibeComment comment) async {
    if (!_hasBackendId || comment.id.trim().isEmpty) return;
    try {
      final result = await _api.toggleCommentLike(widget.vibe.id, comment.id);
      if (!mounted) return;
      setState(() {
        final index = _comments.indexWhere((item) => item.id == result.commentId);
        if (index >= 0) _comments[index] = _comments[index].copyWith(likedByMe: result.likedByMe, likesCount: result.likesCount);
      });
    } catch (error) {
      if (mounted) _toast(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _startReply(VibeComment comment) {
    setState(() {
      _replyingTo = comment;
      _commentController.text = '@${comment.name} ';
      _commentController.selection = TextSelection.fromPosition(TextPosition(offset: _commentController.text.length));
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _commentController.clear();
    });
  }

  Future<void> _toggleCommentPin(VibeComment comment) async {
    if (!_hasBackendId || !comment.canPin || comment.id.trim().isEmpty) return;
    try {
      final isPinned = await _api.toggleCommentPin(widget.vibe.id, comment.id);
      if (!mounted) return;
      setState(() {
        final index = _comments.indexWhere((item) => item.id == comment.id);
        if (index >= 0) _comments[index] = _comments[index].copyWith(isPinned: isPinned);
        _sortComments();
      });
      _toast(isPinned ? 'Comment pinned.' : 'Comment unpinned.');
    } catch (error) {
      if (mounted) _toast(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteComment(VibeComment comment) async {
    if (!_hasBackendId || !comment.canDelete || comment.id.trim().isEmpty) return;
    final shouldDelete = await showModalBottomSheet<bool>(context: context, backgroundColor: Colors.transparent, builder: (_) => const _ConfirmDeleteCommentSheet());
    if (shouldDelete != true || !mounted) return;
    try {
      await _api.deleteComment(widget.vibe.id, comment.id);
      if (!mounted) return;
      setState(() {
        final removed = _comments.where((item) => item.id == comment.id || item.parentCommentId == comment.id).length;
        _comments.removeWhere((item) => item.id == comment.id || item.parentCommentId == comment.id);
        _commentsCount = _commentsCount - removed;
        if (_commentsCount < 0) _commentsCount = 0;
      });
      widget.onCommentAdded?.call();
      _toast('Comment deleted.');
    } catch (error) {
      if (mounted) _toast(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openCommentActions(VibeComment comment) async {
    if (!comment.canPin && !comment.canDelete) return;
    final action = await showModalBottomSheet<_CommentAction>(context: context, backgroundColor: Colors.transparent, builder: (_) => _CommentActionsSheet(comment: comment));
    if (!mounted || action == null) return;
    switch (action) {
      case _CommentAction.pin:
        await _toggleCommentPin(comment);
      case _CommentAction.delete:
        await _deleteComment(comment);
    }
  }

  Future<void> _deleteVibe() async {
    if (!_isSelfVibe || _deleting) return;
    final shouldDelete = await showModalBottomSheet<bool>(context: context, backgroundColor: Colors.transparent, builder: (_) => const _ConfirmDeleteSheet());
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

  Future<void> _openCommentsOverlay() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> runAndRefresh(Future<void> Function() action) async {
            await action();
            if (context.mounted) setSheetState(() {});
          }

          return _CommentsOverlaySheet(
            comments: _orderedComments(),
            commentsCount: _commentsCount,
            loading: _loadingComments,
            error: _error,
            canComment: _canComment,
            sending: _sendingComment,
            controller: _commentController,
            focusNode: _commentFocusNode,
            replyingTo: _replyingTo,
            onRefresh: () => runAndRefresh(_loadComments),
            onRetry: () => runAndRefresh(_loadComments),
            onSend: () => runAndRefresh(_sendComment),
            onCancelReply: () {
              _cancelReply();
              setSheetState(() {});
            },
            onReplyTap: (comment) {
              _startReply(comment);
              setSheetState(() {});
            },
            onLikeTap: (comment) => runAndRefresh(() => _toggleCommentLike(comment)),
            onActionsTap: (comment) => runAndRefresh(() => _openCommentActions(comment)),
          );
        },
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF111015)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isMediaVibe) return _buildReelDetail(context);
    return _buildTextDetail(context);
  }

  Widget _buildReelDetail(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(onDoubleTap: () => unawaited(_toggleVibeLike()), child: VibeMediaPlayer(vibe: widget.vibe, onDoubleTap: () => unawaited(_toggleVibeLike()))),
          const _ReelGradientOverlay(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
              child: Column(
                children: [
                  Row(children: [_GlassCircleButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)), const Spacer(), if (_isSelfVibe) _GlassCircleButton(icon: _deleting ? Icons.hourglass_top_rounded : Icons.delete_outline_rounded, onTap: () => unawaited(_deleteVibe()))]),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _ReelAuthorCaption(vibe: widget.vibe, caption: _caption)),
                      const SizedBox(width: 12),
                      _ReelActionRail(likedByMe: _likedByMe, savedByMe: _savedByMe, likes: _likesCount, comments: _commentsCount, shares: _sharesCount, saves: _savesCount, onLike: () => unawaited(_toggleVibeLike()), onComments: () => unawaited(_openCommentsOverlay()), onShare: () => unawaited(_shareVibe()), onSave: () => unawaited(_toggleVibeSave())),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextDetail(BuildContext context) {
    final orderedComments = _orderedComments();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111015), size: 26)),
        title: const Text('Vibe', style: TextStyle(color: Color(0xFF111015), fontSize: 18, fontWeight: FontWeight.w900)),
        actions: [
          if (_isSelfVibe) IconButton(onPressed: _deleting ? null : _deleteVibe, icon: Icon(_deleting ? Icons.hourglass_top_rounded : Icons.delete_outline_rounded, color: const Color(0xFFE84C72), size: 24)),
          IconButton(onPressed: () => unawaited(_openCommentsOverlay()), icon: const Icon(Icons.mode_comment_outlined, color: Color(0xFF111015), size: 23)),
          const SizedBox(width: 6),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: Color(0xFFECE2D8))),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF111015),
          onRefresh: _loadComments,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: _DetailPost(vibe: widget.vibe, caption: _caption, likes: _likesCount, comments: _commentsCount, shares: _sharesCount, saves: _savesCount)),
              if (!widget.vibe.commentsEnabled) const SliverToBoxAdapter(child: _CommentsOffNotice()),
              SliverToBoxAdapter(child: _CommentsHeader(count: _commentsCount, loading: _loadingComments, onRefresh: _loadComments)),
              if (_error != null) SliverToBoxAdapter(child: _ErrorCard(message: _error!, onRetry: _loadComments)),
              if (_comments.isEmpty && !_loadingComments && _error == null)
                const SliverToBoxAdapter(child: _EmptyCommentsState())
              else
                SliverList.builder(itemCount: orderedComments.length, itemBuilder: (context, index) {
                  final comment = orderedComments[index];
                  return _CommentTile(comment: comment, onLikeTap: () => unawaited(_toggleCommentLike(comment)), onReplyTap: () => _startReply(comment), onActionsTap: () => unawaited(_openCommentActions(comment)));
                }),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(top: false, child: _CommentComposer(controller: _commentController, focusNode: _commentFocusNode, sending: _sendingComment, enabled: _canComment, replyingTo: _replyingTo, onCancelReply: _cancelReply, onSend: _sendComment)),
    );
  }
}

class _ReelGradientOverlay extends StatelessWidget {
  const _ReelGradientOverlay();
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent, Colors.black.withValues(alpha: 0.76)], stops: const [0, 0.42, 1])),
        ),
      );
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, customBorder: const CircleBorder(), child: Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.32), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.16))), child: Icon(icon, color: Colors.white, size: 23)));
}

class _ReelAuthorCaption extends StatelessWidget {
  const _ReelAuthorCaption({required this.vibe, required this.caption});
  final VibeItem vibe;
  final String caption;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [VibeAvatar(vibe: vibe, size: 38), const SizedBox(width: 10), Expanded(child: Text(vibe.authorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))), Text(vibe.timeAgo, style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 11, fontWeight: FontWeight.w800))]),
        if (caption.isNotEmpty) ...[const SizedBox(height: 10), _CaptionText(caption: caption, color: Colors.white, mentionColor: const Color(0xFF9DB7FF), fontSize: 13.4)],
      ]);
}

class _ReelActionRail extends StatelessWidget {
  const _ReelActionRail({required this.likedByMe, required this.savedByMe, required this.likes, required this.comments, required this.shares, required this.saves, required this.onLike, required this.onComments, required this.onShare, required this.onSave});
  final bool likedByMe;
  final bool savedByMe;
  final int likes;
  final int comments;
  final int shares;
  final int saves;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onShare;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        _ReelRailButton(icon: likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: likedByMe ? const Color(0xFFE84C72) : Colors.white, label: _formatCount(likes), onTap: onLike),
        _ReelRailButton(icon: Icons.mode_comment_rounded, label: _formatCount(comments), onTap: onComments),
        _ReelRailButton(icon: Icons.send_rounded, label: _formatCount(shares), onTap: onShare),
        _ReelRailButton(icon: savedByMe ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, label: _formatCount(saves), onTap: onSave),
      ]);
}

class _ReelRailButton extends StatelessWidget {
  const _ReelRailButton({required this.icon, required this.label, required this.onTap, this.color = Colors.white});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 18), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(999), child: Column(children: [Icon(icon, color: color, size: 31), const SizedBox(height: 4), Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900))])));
}

class _CommentsOverlaySheet extends StatelessWidget {
  const _CommentsOverlaySheet({required this.comments, required this.commentsCount, required this.loading, required this.error, required this.canComment, required this.sending, required this.controller, required this.focusNode, required this.replyingTo, required this.onRefresh, required this.onRetry, required this.onSend, required this.onCancelReply, required this.onReplyTap, required this.onLikeTap, required this.onActionsTap});
  final List<VibeComment> comments;
  final int commentsCount;
  final bool loading;
  final String? error;
  final bool canComment;
  final bool sending;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VibeComment? replyingTo;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRetry;
  final Future<void> Function() onSend;
  final VoidCallback onCancelReply;
  final void Function(VibeComment comment) onReplyTap;
  final void Function(VibeComment comment) onLikeTap;
  final void Function(VibeComment comment) onActionsTap;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.42,
        maxChildSize: 0.94,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(children: [
            const SizedBox(height: 10),
            Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999))),
            _CommentsHeader(count: commentsCount, loading: loading, onRefresh: () => unawaited(onRefresh())),
            if (error != null) _ErrorCard(message: error!, onRetry: () => unawaited(onRetry())),
            Expanded(
              child: comments.isEmpty && !loading && error == null
                  ? const _EmptyCommentsState()
                  : ListView.builder(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return _CommentTile(comment: comment, onLikeTap: () => onLikeTap(comment), onReplyTap: () => onReplyTap(comment), onActionsTap: () => onActionsTap(comment));
                      },
                    ),
            ),
            _CommentComposer(controller: controller, focusNode: focusNode, sending: sending, enabled: canComment, replyingTo: replyingTo, onCancelReply: onCancelReply, onSend: () => unawaited(onSend())),
          ]),
        ),
      );
}

class _DetailPost extends StatelessWidget {
  const _DetailPost({required this.vibe, required this.caption, required this.likes, required this.comments, required this.shares, required this.saves});
  final VibeItem vibe;
  final String caption;
  final int likes;
  final int comments;
  final int shares;
  final int saves;

  @override
  Widget build(BuildContext context) => ColoredBox(color: Colors.white, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_AuthorRow(vibe: vibe), _PostInfo(vibe: vibe, caption: caption, likes: likes, comments: comments, shares: shares, saves: saves), const Divider(height: 1, color: Color(0xFFECE2D8))]));
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.vibe});
  final VibeItem vibe;
  @override
  Widget build(BuildContext context) => SizedBox(height: 58, child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 8), child: Row(children: [VibeAvatar(vibe: vibe, size: 38), const SizedBox(width: 10), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(vibe.authorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF111015), fontSize: 14, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(vibe.timeAgo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 11.5, fontWeight: FontWeight.w700))]))])));
}

class _PostInfo extends StatelessWidget {
  const _PostInfo({required this.vibe, required this.caption, required this.likes, required this.comments, required this.shares, required this.saves});
  final VibeItem vibe;
  final String caption;
  final int likes;
  final int comments;
  final int shares;
  final int saves;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(14, 6, 14, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (caption.isNotEmpty) ...[_CaptionText(caption: caption, color: const Color(0xFF111015), mentionColor: const Color(0xFF3859D6), fontSize: 16), const SizedBox(height: 14)], Row(children: [_Metric(icon: Icons.favorite_rounded, value: likes), const SizedBox(width: 14), _Metric(icon: Icons.mode_comment_rounded, value: comments), const SizedBox(width: 14), _Metric(icon: Icons.send_rounded, value: shares), const SizedBox(width: 14), _Metric(icon: Icons.bookmark_rounded, value: saves)]), const SizedBox(height: 8), Text(vibe.timeAgo.toUpperCase(), style: const TextStyle(color: Color(0xFF8C8198), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.2))]));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value});
  final IconData icon;
  final int value;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: const Color(0xFF111015), size: 19), const SizedBox(width: 5), Text(_formatCount(value), style: const TextStyle(color: Color(0xFF111015), fontSize: 12.5, fontWeight: FontWeight.w900))]);
}

class _CaptionText extends StatelessWidget {
  const _CaptionText({required this.caption, required this.color, required this.mentionColor, required this.fontSize});
  final String caption;
  final Color color;
  final Color mentionColor;
  final double fontSize;
  static final RegExp _mentionPattern = RegExp(r'@[A-Za-z0-9_]+');
  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    var index = 0;
    for (final match in _mentionPattern.allMatches(caption)) {
      if (match.start > index) spans.add(TextSpan(text: caption.substring(index, match.start)));
      spans.add(TextSpan(text: caption.substring(match.start, match.end), style: TextStyle(color: mentionColor, fontWeight: FontWeight.w900)));
      index = match.end;
    }
    if (index < caption.length) spans.add(TextSpan(text: caption.substring(index)));
    return RichText(text: TextSpan(style: TextStyle(color: color, fontSize: fontSize, height: 1.35, fontWeight: FontWeight.w600), children: spans));
  }
}

class _CommentsOffNotice extends StatelessWidget {
  const _CommentsOffNotice();
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.fromLTRB(14, 12, 14, 4), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF7F3EF), borderRadius: BorderRadius.circular(16)), child: const Row(children: [Icon(Icons.comments_disabled_rounded, color: Color(0xFF8C8198), size: 18), SizedBox(width: 8), Expanded(child: Text('Comments are off for this Vibe.', style: TextStyle(color: Color(0xFF8C8198), fontSize: 12, fontWeight: FontWeight.w800)))]));
}

class _CommentsHeader extends StatelessWidget {
  const _CommentsHeader({required this.count, required this.loading, required this.onRefresh});
  final int count;
  final bool loading;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(14, 14, 8, 8), child: Row(children: [Expanded(child: Text('Comments  ${_formatCount(count)}', style: const TextStyle(color: Color(0xFF111015), fontSize: 17, fontWeight: FontWeight.w900))), if (loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111015))) else IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded, color: Color(0xFF111015), size: 20))]));
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.onLikeTap, required this.onReplyTap, required this.onActionsTap});
  final VibeComment comment;
  final VoidCallback onLikeTap;
  final VoidCallback onReplyTap;
  final VoidCallback onActionsTap;
  @override
  Widget build(BuildContext context) {
    final avatarUrl = comment.avatarUrl?.trim();
    final isReply = comment.isReply;
    return Container(color: comment.isPinned ? const Color(0xFFFFFBF3) : Colors.white, padding: EdgeInsets.fromLTRB(isReply ? 58 : 14, 8, 8, 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [if (isReply) Container(width: 18, height: 1, margin: const EdgeInsets.only(top: 16, right: 8), color: const Color(0xFFE0D5CB)), Container(width: isReply ? 28 : 34, height: isReply ? 28 : 34, clipBehavior: Clip.antiAlias, decoration: const BoxDecoration(color: Color(0xFF111015), shape: BoxShape.circle), child: avatarUrl != null && avatarUrl.isNotEmpty ? Image.network(avatarUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => _CommentAvatarFallback(comment: comment)) : _CommentAvatarFallback(comment: comment)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (comment.isPinned) const Padding(padding: EdgeInsets.only(bottom: 4), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.push_pin_rounded, color: Color(0xFFC99A3B), size: 13), SizedBox(width: 4), Text('Pinned', style: TextStyle(color: Color(0xFFC99A3B), fontSize: 10.5, fontWeight: FontWeight.w900))])), RichText(text: TextSpan(style: const TextStyle(color: Color(0xFF111015), fontSize: 13.2, height: 1.32), children: [TextSpan(text: '${comment.name} ', style: const TextStyle(fontWeight: FontWeight.w900)), TextSpan(text: comment.text, style: const TextStyle(fontWeight: FontWeight.w600))])), const SizedBox(height: 6), Row(children: [Text(comment.time, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 10.5, fontWeight: FontWeight.w700)), const SizedBox(width: 14), if (comment.likesCount > 0) ...[Text('${_formatCount(comment.likesCount)} like${comment.likesCount == 1 ? '' : 's'}', style: const TextStyle(color: Color(0xFF8C8198), fontSize: 10.5, fontWeight: FontWeight.w800)), const SizedBox(width: 14)], InkWell(onTap: onReplyTap, borderRadius: BorderRadius.circular(999), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2), child: Text('Reply', style: TextStyle(color: Color(0xFF8C8198), fontSize: 11, fontWeight: FontWeight.w900))))])])), InkWell(onTap: onLikeTap, customBorder: const CircleBorder(), child: Padding(padding: const EdgeInsets.all(9), child: Icon(comment.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: comment.likedByMe ? const Color(0xFFE84C72) : const Color(0xFF8C8198), size: 18))), if (comment.canPin || comment.canDelete) IconButton(onPressed: onActionsTap, icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF8C8198), size: 20))]));
  }
}

class _CommentAvatarFallback extends StatelessWidget {
  const _CommentAvatarFallback({required this.comment});
  final VibeComment comment;
  @override
  Widget build(BuildContext context) => Center(child: Text(comment.avatarText, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)));
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({required this.controller, required this.focusNode, required this.sending, required this.enabled, required this.replyingTo, required this.onCancelReply, required this.onSend});
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final bool enabled;
  final VibeComment? replyingTo;
  final VoidCallback onCancelReply;
  final VoidCallback onSend;
  @override
  Widget build(BuildContext context) {
    final canSend = enabled && !sending;
    final replyTarget = replyingTo;
    return Container(padding: EdgeInsets.fromLTRB(12, 8, 12, 10 + MediaQuery.paddingOf(context).bottom), decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFECE2D8)))), child: Column(mainAxisSize: MainAxisSize.min, children: [if (replyTarget != null) Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFF7F3EF), borderRadius: BorderRadius.circular(999)), child: Row(children: [const Icon(Icons.reply_rounded, color: Color(0xFF8C8198), size: 16), const SizedBox(width: 7), Expanded(child: Text('Replying to ${replyTarget.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 12, fontWeight: FontWeight.w900))), InkWell(onTap: onCancelReply, customBorder: const CircleBorder(), child: const Padding(padding: EdgeInsets.all(2), child: Icon(Icons.close_rounded, color: Color(0xFF8C8198), size: 17)))])), Row(children: [Expanded(child: TextField(controller: controller, focusNode: focusNode, enabled: canSend, minLines: 1, maxLines: 3, decoration: InputDecoration(hintText: enabled ? (replyTarget == null ? 'Add a comment...' : 'Add a reply...') : 'Comments are off', hintStyle: const TextStyle(color: Color(0xFFAAA1AE), fontWeight: FontWeight.w600), filled: true, fillColor: const Color(0xFFF7F3EF), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none)))), const SizedBox(width: 8), InkWell(onTap: canSend ? onSend : null, borderRadius: BorderRadius.circular(999), child: Container(width: 43, height: 43, decoration: BoxDecoration(color: enabled ? const Color(0xFF111015) : const Color(0xFFE4DFE8), shape: BoxShape.circle), child: sending ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(Icons.arrow_upward_rounded, color: enabled ? Colors.white : const Color(0xFF8C8198), size: 22)))])]));
  }
}

class _EmptyCommentsState extends StatelessWidget {
  const _EmptyCommentsState();
  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.fromLTRB(14, 24, 14, 28), child: Center(child: Text('No comments yet. Be the first to comment.', style: TextStyle(color: Color(0xFF8C8198), fontWeight: FontWeight.w800))));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.fromLTRB(14, 4, 14, 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF8E8), borderRadius: BorderRadius.circular(14)), child: Row(children: [const Icon(Icons.wifi_off_rounded, color: Color(0xFFC99A3B), size: 19), const SizedBox(width: 9), Expanded(child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800))), TextButton(onPressed: onRetry, child: const Text('Retry'))]));
}

class _ConfirmDeleteSheet extends StatelessWidget {
  const _ConfirmDeleteSheet();
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.all(14), padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + MediaQuery.paddingOf(context).bottom), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Delete this Vibe?', style: TextStyle(color: Color(0xFF111015), fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 8), const Text('This removes the Vibe from the feed.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8C8198), fontWeight: FontWeight.w700)), const SizedBox(height: 16), Row(children: [Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel'))), const SizedBox(width: 10), Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE84C72), foregroundColor: Colors.white), onPressed: () => Navigator.pop(context, true), child: const Text('Delete')))])]));
}

class _ConfirmDeleteCommentSheet extends StatelessWidget {
  const _ConfirmDeleteCommentSheet();
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.all(14), padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + MediaQuery.paddingOf(context).bottom), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Delete this comment?', style: TextStyle(color: Color(0xFF111015), fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 8), const Text('This removes the comment from this Vibe.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8C8198), fontWeight: FontWeight.w700)), const SizedBox(height: 16), Row(children: [Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel'))), const SizedBox(width: 10), Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE84C72), foregroundColor: Colors.white), onPressed: () => Navigator.pop(context, true), child: const Text('Delete')))])]));
}

enum _CommentAction { pin, delete }

class _CommentActionsSheet extends StatelessWidget {
  const _CommentActionsSheet({required this.comment});
  final VibeComment comment;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.all(14), padding: EdgeInsets.fromLTRB(14, 12, 14, 14 + MediaQuery.paddingOf(context).bottom), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 24, offset: const Offset(0, 10))]), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999))), const SizedBox(height: 12), if (comment.canPin) _CommentActionTile(icon: comment.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, title: comment.isPinned ? 'Unpin comment' : 'Pin comment', color: const Color(0xFFC99A3B), onTap: () => Navigator.pop(context, _CommentAction.pin)), if (comment.canDelete) _CommentActionTile(icon: Icons.delete_outline_rounded, title: 'Delete comment', color: const Color(0xFFE84C72), onTap: () => Navigator.pop(context, _CommentAction.delete))]));
}

class _CommentActionTile extends StatelessWidget {
  const _CommentActionTile({required this.icon, required this.title, required this.color, required this.onTap});
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18)), child: Row(children: [Icon(icon, color: color, size: 21), const SizedBox(width: 10), Expanded(child: Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900))), const Icon(Icons.chevron_right_rounded, color: Color(0xFF8C8198))])));
}

String _formatCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  return '$value';
}
