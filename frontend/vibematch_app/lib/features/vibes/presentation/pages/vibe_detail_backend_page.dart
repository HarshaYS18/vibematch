import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/vibe_detail_controller.dart';
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
  late final VibeDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VibeDetailController(
      vibe: widget.vibe,
      onCommentChanged: widget.onCommentAdded,
      onDeleteVibe: widget.onDeleteVibe,
    )..addListener(_onControllerChanged);
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _runAction(Future<String?> Function() action, {bool popOnSuccess = false}) async {
    try {
      final message = await action();
      if (!mounted) return;
      if (message != null && message.trim().isNotEmpty) _toast(message);
      if (popOnSuccess) Navigator.pop(context);
    } catch (error) {
      if (mounted) _toast(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _confirmAndDeleteVibe() async {
    if (!_controller.isSelfVibe || _controller.deleting) return;
    final shouldDelete = await showModalBottomSheet<bool>(context: context, backgroundColor: Colors.transparent, builder: (_) => const VibeConfirmDeleteSheet());
    if (shouldDelete != true || !mounted) return;
    await _runAction(_controller.deleteVibe, popOnSuccess: true);
  }

  Future<void> _confirmAndDeleteComment(VibeComment comment) async {
    final shouldDelete = await showModalBottomSheet<bool>(context: context, backgroundColor: Colors.transparent, builder: (_) => const VibeConfirmDeleteCommentSheet());
    if (shouldDelete != true || !mounted) return;
    await _runAction(() => _controller.deleteComment(comment));
  }

  Future<void> _openCommentActions(VibeComment comment) async {
    if (!comment.canPin && !comment.canDelete) return;
    final action = await showModalBottomSheet<VibeDetailCommentAction>(context: context, backgroundColor: Colors.transparent, builder: (_) => VibeCommentActionsSheet(comment: comment));
    if (!mounted || action == null) return;
    switch (action) {
      case VibeDetailCommentAction.pin:
        await _runAction(() => _controller.toggleCommentPin(comment));
      case VibeDetailCommentAction.delete:
        await _confirmAndDeleteComment(comment);
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

          Future<void> runMessageAndRefresh(Future<String?> Function() action) async {
            await _runAction(action);
            if (context.mounted) setSheetState(() {});
          }

          return VibeDetailCommentsOverlaySheet(
            comments: _controller.orderedComments,
            commentsCount: _controller.commentsCount,
            loading: _controller.loadingComments,
            error: _controller.error,
            canComment: _controller.canComment,
            sending: _controller.sendingComment,
            controller: _controller.commentController,
            focusNode: _controller.commentFocusNode,
            replyingTo: _controller.replyingTo,
            onRefresh: () => runAndRefresh(_controller.loadComments),
            onRetry: () => runAndRefresh(_controller.loadComments),
            onSend: () => runMessageAndRefresh(_controller.sendComment),
            onCancelReply: () {
              _controller.cancelReply();
              setSheetState(() {});
            },
            onReplyTap: (comment) {
              _controller.startReply(comment);
              setSheetState(() {});
            },
            onLikeTap: (comment) => runAndRefresh(() => _controller.toggleCommentLike(comment)),
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
    if (_controller.isMediaVibe) {
      return VibeLegacyReelDetail(
        vibe: widget.vibe,
        caption: _controller.caption,
        likedByMe: _controller.likedByMe,
        savedByMe: _controller.savedByMe,
        likes: _controller.likesCount,
        comments: _controller.commentsCount,
        shares: _controller.sharesCount,
        saves: _controller.savesCount,
        isSelfVibe: _controller.isSelfVibe,
        deleting: _controller.deleting,
        onBack: () => Navigator.pop(context),
        onDelete: () => unawaited(_confirmAndDeleteVibe()),
        onLike: () => unawaited(_runAction(_controller.toggleVibeLike)),
        onComments: () => unawaited(_openCommentsOverlay()),
        onShare: () => unawaited(_runAction(_controller.shareVibe)),
        onSave: () => unawaited(_runAction(_controller.toggleVibeSave)),
      );
    }

    return VibeTextDetailView(
      caption: _controller.caption,
      timeAgo: widget.vibe.timeAgo,
      likes: _controller.likesCount,
      commentsCount: _controller.commentsCount,
      shares: _controller.sharesCount,
      saves: _controller.savesCount,
      commentsEnabled: widget.vibe.commentsEnabled,
      comments: _controller.orderedComments,
      loadingComments: _controller.loadingComments,
      error: _controller.error,
      isSelfVibe: _controller.isSelfVibe,
      deleting: _controller.deleting,
      canComment: _controller.canComment,
      sendingComment: _controller.sendingComment,
      commentController: _controller.commentController,
      commentFocusNode: _controller.commentFocusNode,
      replyingTo: _controller.replyingTo,
      onBack: () => Navigator.pop(context),
      onDeleteVibe: () => unawaited(_confirmAndDeleteVibe()),
      onOpenCommentsOverlay: () => unawaited(_openCommentsOverlay()),
      onRefreshComments: _controller.loadComments,
      onCommentLike: (comment) => unawaited(_runAction(() async {
        await _controller.toggleCommentLike(comment);
        return null;
      })),
      onCommentReply: _controller.startReply,
      onCommentActions: (comment) => unawaited(_openCommentActions(comment)),
      onCancelReply: _controller.cancelReply,
      onSendComment: _controller.sendComment,
    );
  }
}
