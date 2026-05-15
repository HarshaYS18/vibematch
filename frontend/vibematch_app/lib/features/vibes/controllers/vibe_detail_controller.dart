import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/data/auth_api_service.dart';
import '../data/vibes_api_service.dart';
import '../models/vibe_models.dart';

class VibeDetailController extends ChangeNotifier {
  VibeDetailController({
    required this.vibe,
    this.api = const VibesApiService(),
    this.authApi = const AuthApiService(),
    this.onCommentChanged,
    this.onDeleteVibe,
  })  : likedByMe = vibe.likedByMe,
        savedByMe = vibe.savedByMe,
        likesCount = vibe.likes,
        commentsCount = vibe.comments,
        sharesCount = vibe.shares,
        savesCount = vibe.saves;

  final VibeItem vibe;
  final VibesApiService api;
  final AuthApiService authApi;
  final VoidCallback? onCommentChanged;
  final Future<void> Function()? onDeleteVibe;

  final TextEditingController commentController = TextEditingController();
  final FocusNode commentFocusNode = FocusNode();
  final List<VibeComment> _comments = <VibeComment>[];

  bool likedByMe;
  bool savedByMe;
  int likesCount;
  int commentsCount;
  int sharesCount;
  int savesCount;
  bool loadingComments = false;
  bool sendingComment = false;
  bool deleting = false;
  String? error;
  VibeComment? replyingTo;

  bool get isSelfVibe => authApi.cachedUser?.publicUserId.toString() == vibe.authorId;
  bool get hasBackendId => vibe.id.trim().isNotEmpty;
  bool get canComment => vibe.commentsEnabled || isSelfVibe;
  bool get isMediaVibe => vibe.mediaType != VibeMediaType.text;

  String get caption {
    final baseCaption = vibe.caption.trim();
    final extras = <String>[];
    for (final raw in vibe.mentions) {
      final clean = raw.trim();
      if (clean.isEmpty) continue;
      final token = clean.startsWith('@') ? clean : '@$clean';
      if (!baseCaption.toLowerCase().contains(token.toLowerCase()) && !extras.contains(token)) extras.add(token);
    }
    if (vibe.usesMentionAll && !baseCaption.toLowerCase().contains('@all')) extras.add('@all');
    return extras.isEmpty ? baseCaption : '$baseCaption ${extras.join(' ')}';
  }

  List<VibeComment> get orderedComments {
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

  Future<void> initialize() async {
    await loadComments();
  }

  @override
  void dispose() {
    commentFocusNode.dispose();
    commentController.dispose();
    super.dispose();
  }

  void _sortComments() {
    _comments.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      if (a.isReply != b.isReply) return a.isReply ? 1 : -1;
      return 0;
    });
  }

  Future<void> loadComments() async {
    if (!hasBackendId || loadingComments) return;
    loadingComments = true;
    error = null;
    notifyListeners();
    try {
      final loadedComments = await api.loadComments(vibe.id);
      _comments
        ..clear()
        ..addAll(loadedComments);
      _sortComments();
      commentsCount = loadedComments.length;
    } catch (caughtError) {
      error = caughtError.toString().replaceFirst('Exception: ', '');
    } finally {
      loadingComments = false;
      notifyListeners();
    }
  }

  Future<String?> toggleVibeLike() async {
    if (!hasBackendId) return null;
    final result = await api.toggleLike(vibe.id);
    likedByMe = result.likedByMe;
    likesCount = result.likesCount;
    notifyListeners();
    return null;
  }

  Future<String?> toggleVibeSave() async {
    if (!hasBackendId) return null;
    final result = await api.toggleSave(vibe.id);
    savedByMe = result.savedByMe;
    savesCount = result.savesCount;
    notifyListeners();
    return result.savedByMe ? 'Saved Vibe.' : 'Removed from saved Vibes.';
  }

  Future<String?> shareVibe() async {
    if (!hasBackendId) return null;
    final result = await api.shareVibe(vibe.id, shareChannel: 'detail');
    sharesCount = result.sharesCount;
    notifyListeners();
    return 'Vibe shared.';
  }

  Future<String?> sendComment() async {
    if (!canComment) return 'Comments are off for this Vibe.';
    final text = commentController.text.trim();
    if (text.isEmpty || sendingComment) return null;
    if (!hasBackendId) return 'Refresh feed and open this Vibe again.';
    final parentCommentId = replyingTo?.parentCommentId ?? replyingTo?.id;
    sendingComment = true;
    notifyListeners();
    try {
      final comment = await api.addComment(vibe.id, text, parentCommentId: parentCommentId);
      _comments.add(comment);
      _sortComments();
      commentsCount += 1;
      commentController.clear();
      replyingTo = null;
      onCommentChanged?.call();
      return null;
    } finally {
      sendingComment = false;
      notifyListeners();
    }
  }

  Future<void> toggleCommentLike(VibeComment comment) async {
    if (!hasBackendId || comment.id.trim().isEmpty) return;
    final result = await api.toggleCommentLike(vibe.id, comment.id);
    final index = _comments.indexWhere((item) => item.id == result.commentId);
    if (index >= 0) _comments[index] = _comments[index].copyWith(likedByMe: result.likedByMe, likesCount: result.likesCount);
    notifyListeners();
  }

  void startReply(VibeComment comment) {
    replyingTo = comment;
    commentController.text = '@${comment.name} ';
    commentController.selection = TextSelection.fromPosition(TextPosition(offset: commentController.text.length));
    commentFocusNode.requestFocus();
    notifyListeners();
  }

  void cancelReply() {
    replyingTo = null;
    commentController.clear();
    notifyListeners();
  }

  Future<String?> toggleCommentPin(VibeComment comment) async {
    if (!hasBackendId || !comment.canPin || comment.id.trim().isEmpty) return null;
    final isPinned = await api.toggleCommentPin(vibe.id, comment.id);
    final index = _comments.indexWhere((item) => item.id == comment.id);
    if (index >= 0) _comments[index] = _comments[index].copyWith(isPinned: isPinned);
    _sortComments();
    notifyListeners();
    return isPinned ? 'Comment pinned.' : 'Comment unpinned.';
  }

  Future<String?> deleteComment(VibeComment comment) async {
    if (!hasBackendId || !comment.canDelete || comment.id.trim().isEmpty) return null;
    await api.deleteComment(vibe.id, comment.id);
    final removed = _comments.where((item) => item.id == comment.id || item.parentCommentId == comment.id).length;
    _comments.removeWhere((item) => item.id == comment.id || item.parentCommentId == comment.id);
    commentsCount -= removed;
    if (commentsCount < 0) commentsCount = 0;
    onCommentChanged?.call();
    notifyListeners();
    return 'Comment deleted.';
  }

  Future<String?> deleteVibe() async {
    if (!isSelfVibe || deleting) return null;
    deleting = true;
    notifyListeners();
    try {
      await onDeleteVibe?.call();
      return 'Vibe deleted.';
    } finally {
      deleting = false;
      notifyListeners();
    }
  }
}
