import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/vibe_detail_controller.dart';
import '../../models/vibe_models.dart';
import '../widgets/vibe_detail_widgets.dart';

class VibeDetailBackendPage extends ConsumerStatefulWidget {
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
  ConsumerState<VibeDetailBackendPage> createState() =>
      _VibeDetailBackendPageState();
}

class _VibeDetailBackendPageState
    extends ConsumerState<VibeDetailBackendPage> {
  late final VibeDetailArgs _providerArgs;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  VibeDetailController get _controller =>
      ref.read(vibeDetailControllerProvider(_providerArgs).notifier);

  @override
  void initState() {
    super.initState();
    _providerArgs = VibeDetailArgs(
      vibe: widget.vibe,
      onCommentChanged: widget.onCommentAdded,
      onDeleteVibe: widget.onDeleteVibe,
    );
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _commentFocusNode.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _runAction(
    Future<String?> Function() action, {
    bool popOnSuccess = false,
  }) async {
    try {
      final message = await action();
      if (!mounted) return;
      if (message != null && message.trim().isNotEmpty) {
        _toast(message);
      }
      if (popOnSuccess) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        _toast(error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<String?> _sendComment() async {
    final before = ref.read(vibeDetailControllerProvider(_providerArgs));
    final text = _commentController.text;
    final message = await _controller.sendComment(text);
    if (message == null &&
        before.canComment &&
        before.hasBackendId &&
        !before.sendingComment &&
        text.trim().isNotEmpty) {
      _commentController.clear();
    }
    return message;
  }

  void _startReply(VibeComment comment) {
    _controller.startReply(comment);
    _commentController.text = '@${comment.name} ';
    _commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _commentController.text.length),
    );
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    _controller.cancelReply();
    _commentController.clear();
  }

  Future<void> _confirmAndDeleteVibe() async {
    final detail = ref.read(vibeDetailControllerProvider(_providerArgs));
    if (!detail.isSelfVibe || detail.deleting) return;
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const VibeConfirmDeleteSheet(),
    );
    if (shouldDelete != true || !mounted) return;
    await _runAction(_controller.deleteVibe, popOnSuccess: true);
  }

  Future<void> _confirmAndDeleteComment(VibeComment comment) async {
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const VibeConfirmDeleteCommentSheet(),
    );
    if (shouldDelete != true || !mounted) return;
    await _runAction(() => _controller.deleteComment(comment));
  }

  Future<void> _openCommentActions(VibeComment comment) async {
    if (!comment.canPin && !comment.canDelete) return;
    final action = await showModalBottomSheet<VibeDetailCommentAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => VibeCommentActionsSheet(comment: comment),
    );
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
      builder: (_) => Consumer(
        builder: (context, ref, child) {
          final detail = ref.watch(
            vibeDetailControllerProvider(_providerArgs),
          );
          final controller = ref.read(
            vibeDetailControllerProvider(_providerArgs).notifier,
          );
          return VibeDetailCommentsOverlaySheet(
            comments: detail.orderedComments,
            commentsCount: detail.commentsCount,
            loading: detail.loadingComments,
            error: detail.error,
            canComment: detail.canComment,
            sending: detail.sendingComment,
            controller: _commentController,
            focusNode: _commentFocusNode,
            replyingTo: detail.replyingTo,
            onRefresh: controller.loadComments,
            onRetry: controller.loadComments,
            onSend: () async => _runAction(_sendComment),
            onCancelReply: _cancelReply,
            onReplyTap: _startReply,
            onLikeTap: (comment) => unawaited(
              controller.toggleCommentLike(comment),
            ),
            onActionsTap: (comment) =>
                unawaited(_openCommentActions(comment)),
          );
        },
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF111015),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(vibeDetailControllerProvider(_providerArgs));
    final controller = ref.read(
      vibeDetailControllerProvider(_providerArgs).notifier,
    );

    if (detail.isMediaVibe) {
      return VibeLegacyReelDetail(
        vibe: widget.vibe,
        caption: detail.caption,
        likedByMe: detail.likedByMe,
        savedByMe: detail.savedByMe,
        likes: detail.likesCount,
        comments: detail.commentsCount,
        shares: detail.sharesCount,
        saves: detail.savesCount,
        isSelfVibe: detail.isSelfVibe,
        deleting: detail.deleting,
        onBack: () => Navigator.pop(context),
        onDelete: () => unawaited(_confirmAndDeleteVibe()),
        onLike: () => unawaited(_runAction(controller.toggleVibeLike)),
        onComments: () => unawaited(_openCommentsOverlay()),
        onShare: () => unawaited(_runAction(controller.shareVibe)),
        onSave: () => unawaited(_runAction(controller.toggleVibeSave)),
      );
    }

    return VibeTextDetailView(
      caption: detail.caption,
      timeAgo: widget.vibe.timeAgo,
      likes: detail.likesCount,
      commentsCount: detail.commentsCount,
      shares: detail.sharesCount,
      saves: detail.savesCount,
      commentsEnabled: widget.vibe.commentsEnabled,
      comments: detail.orderedComments,
      loadingComments: detail.loadingComments,
      error: detail.error,
      isSelfVibe: detail.isSelfVibe,
      deleting: detail.deleting,
      canComment: detail.canComment,
      sendingComment: detail.sendingComment,
      commentController: _commentController,
      commentFocusNode: _commentFocusNode,
      replyingTo: detail.replyingTo,
      onBack: () => Navigator.pop(context),
      onDeleteVibe: () => unawaited(_confirmAndDeleteVibe()),
      onOpenCommentsOverlay: () => unawaited(_openCommentsOverlay()),
      onRefreshComments: controller.loadComments,
      onCommentLike: (comment) => unawaited(
        _runAction(() async {
          await controller.toggleCommentLike(comment);
          return null;
        }),
      ),
      onCommentReply: _startReply,
      onCommentActions: (comment) =>
          unawaited(_openCommentActions(comment)),
      onCancelReply: _cancelReply,
      onSendComment: _sendComment,
    );
  }
}
