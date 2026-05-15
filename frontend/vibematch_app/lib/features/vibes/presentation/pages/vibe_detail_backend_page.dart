import 'dart:async';

import 'package:flutter/material.dart';

import '../../../auth/data/auth_api_service.dart';
import '../../data/vibes_api_service.dart';
import '../../models/vibe_models.dart';
import '../widgets/vibe_detail_widgets.dart';

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
    final shouldDelete = await showModalBottomSheet<bool>(context: context, backgroundColor: Colors.transparent, builder: (_) => const VibeConfirmDeleteCommentSheet());
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
    final action = await showModalBottomSheet<VibeDetailCommentAction>(context: context, backgroundColor: Colors.transparent, builder: (_) => VibeCommentActionsSheet(comment: comment));
    if (!mounted || action == null) return;
    switch (action) {
      case VibeDetailCommentAction.pin:
        await _toggleCommentPin(comment);
      case VibeDetailCommentAction.delete:
        await _deleteComment(comment);
    }
  }

  Future<void> _deleteVibe() async {
    if (!_isSelfVibe || _deleting) return;
    final shouldDelete = await showModalBottomSheet<bool>(context: context, backgroundColor: Colors.transparent, builder: (_) => const VibeConfirmDeleteSheet());
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

          return VibeDetailCommentsOverlaySheet(
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
    if (_isMediaVibe) {
      return VibeLegacyReelDetail(
        vibe: widget.vibe,
        caption: _caption,
        likedByMe: _likedByMe,
        savedByMe: _savedByMe,
        likes: _likesCount,
        comments: _commentsCount,
        shares: _sharesCount,
        saves: _savesCount,
        isSelfVibe: _isSelfVibe,
        deleting: _deleting,
        onBack: () => Navigator.pop(context),
        onDelete: () => unawaited(_deleteVibe()),
        onLike: () => unawaited(_toggleVibeLike()),
        onComments: () => unawaited(_openCommentsOverlay()),
        onShare: () => unawaited(_shareVibe()),
        onSave: () => unawaited(_toggleVibeSave()),
      );
    }

    return VibeTextDetailView(
      caption: _caption,
      timeAgo: widget.vibe.timeAgo,
      likes: _likesCount,
      commentsCount: _commentsCount,
      shares: _sharesCount,
      saves: _savesCount,
      commentsEnabled: widget.vibe.commentsEnabled,
      comments: _orderedComments(),
      loadingComments: _loadingComments,
      error: _error,
      isSelfVibe: _isSelfVibe,
      deleting: _deleting,
      canComment: _canComment,
      sendingComment: _sendingComment,
      commentController: _commentController,
      commentFocusNode: _commentFocusNode,
      replyingTo: _replyingTo,
      onBack: () => Navigator.pop(context),
      onDeleteVibe: () => unawaited(_deleteVibe()),
      onOpenCommentsOverlay: () => unawaited(_openCommentsOverlay()),
      onRefreshComments: _loadComments,
      onCommentLike: (comment) => unawaited(_toggleCommentLike(comment)),
      onCommentReply: _startReply,
      onCommentActions: (comment) => unawaited(_openCommentActions(comment)),
      onCancelReply: _cancelReply,
      onSendComment: _sendComment,
    );
  }
}
