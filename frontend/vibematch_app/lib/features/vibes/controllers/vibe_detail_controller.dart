import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_api_service.dart';
import '../data/vibes_api_service.dart';
import '../models/vibe_models.dart';

const Object _vibeDetailUnset = Object();

class VibeDetailArgs {
  const VibeDetailArgs({
    required this.vibe,
    this.onCommentChanged,
    this.onDeleteVibe,
  });

  final VibeItem vibe;
  final void Function()? onCommentChanged;
  final Future<void> Function()? onDeleteVibe;
}

class VibeDetailState {
  const VibeDetailState({
    required this.vibe,
    required this.isSelfVibe,
    this.likedByMe = false,
    this.savedByMe = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.savesCount = 0,
    this.loadingComments = false,
    this.sendingComment = false,
    this.deleting = false,
    this.error,
    this.replyingTo,
    this.comments = const <VibeComment>[],
  });

  final VibeItem vibe;
  final bool isSelfVibe;
  final bool likedByMe;
  final bool savedByMe;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int savesCount;
  final bool loadingComments;
  final bool sendingComment;
  final bool deleting;
  final String? error;
  final VibeComment? replyingTo;
  final List<VibeComment> comments;

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
      if (!baseCaption.toLowerCase().contains(token.toLowerCase()) &&
          !extras.contains(token)) {
        extras.add(token);
      }
    }
    if (vibe.usesMentionAll && !baseCaption.toLowerCase().contains('@all')) {
      extras.add('@all');
    }
    return extras.isEmpty ? baseCaption : '$baseCaption ${extras.join(' ')}';
  }

  List<VibeComment> get orderedComments {
    final topLevel =
        comments.where((comment) => !comment.isReply).toList(growable: true);
    topLevel.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return 0;
    });

    final repliesByParent = <String, List<VibeComment>>{};
    for (final reply in comments.where((comment) => comment.isReply)) {
      final parentId = reply.parentCommentId ?? '';
      repliesByParent.putIfAbsent(parentId, () => <VibeComment>[]).add(reply);
    }

    final ordered = <VibeComment>[];
    for (final comment in topLevel) {
      ordered.add(comment);
      ordered.addAll(
        repliesByParent[comment.id] ?? const <VibeComment>[],
      );
    }

    for (final reply in comments.where(
      (comment) =>
          comment.isReply &&
          !topLevel.any((parent) => parent.id == comment.parentCommentId),
    )) {
      ordered.add(reply);
    }
    return ordered;
  }

  VibeDetailState copyWith({
    bool? likedByMe,
    bool? savedByMe,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    int? savesCount,
    bool? loadingComments,
    bool? sendingComment,
    bool? deleting,
    Object? error = _vibeDetailUnset,
    Object? replyingTo = _vibeDetailUnset,
    List<VibeComment>? comments,
  }) {
    return VibeDetailState(
      vibe: vibe,
      isSelfVibe: isSelfVibe,
      likedByMe: likedByMe ?? this.likedByMe,
      savedByMe: savedByMe ?? this.savedByMe,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      savesCount: savesCount ?? this.savesCount,
      loadingComments: loadingComments ?? this.loadingComments,
      sendingComment: sendingComment ?? this.sendingComment,
      deleting: deleting ?? this.deleting,
      error: identical(error, _vibeDetailUnset)
          ? this.error
          : error as String?,
      replyingTo: identical(replyingTo, _vibeDetailUnset)
          ? this.replyingTo
          : replyingTo as VibeComment?,
      comments: List<VibeComment>.unmodifiable(comments ?? this.comments),
    );
  }
}

class VibeDetailController
    extends AutoDisposeFamilyNotifier<VibeDetailState, VibeDetailArgs> {
  final VibesApiService _api = const VibesApiService();
  final AuthApiService _authApi = const AuthApiService();
  late VibeDetailArgs _args;

  @override
  VibeDetailState build(VibeDetailArgs args) {
    _args = args;
    final vibe = args.vibe;
    return VibeDetailState(
      vibe: vibe,
      isSelfVibe:
          _authApi.cachedUser?.publicUserId.toString() == vibe.authorId,
      likedByMe: vibe.likedByMe,
      savedByMe: vibe.savedByMe,
      likesCount: vibe.likes,
      commentsCount: vibe.comments,
      sharesCount: vibe.shares,
      savesCount: vibe.saves,
    );
  }

  Future<void> initialize() => loadComments();

  List<VibeComment> _sorted(List<VibeComment> source) {
    final comments = List<VibeComment>.of(source);
    comments.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      if (a.isReply != b.isReply) return a.isReply ? 1 : -1;
      return 0;
    });
    return comments;
  }

  Future<void> loadComments() async {
    if (!state.hasBackendId || state.loadingComments) return;
    state = state.copyWith(loadingComments: true, error: null);
    try {
      final loadedComments = await _api.loadComments(state.vibe.id);
      state = state.copyWith(
        comments: _sorted(loadedComments),
        commentsCount: loadedComments.length,
        error: null,
      );
    } catch (caughtError) {
      state = state.copyWith(
        error: caughtError.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      state = state.copyWith(loadingComments: false);
    }
  }

  Future<String?> toggleVibeLike() async {
    if (!state.hasBackendId) return null;
    final result = await _api.toggleLike(state.vibe.id);
    state = state.copyWith(
      likedByMe: result.likedByMe,
      likesCount: result.likesCount,
    );
    return null;
  }

  Future<String?> toggleVibeSave() async {
    if (!state.hasBackendId) return null;
    final result = await _api.toggleSave(state.vibe.id);
    state = state.copyWith(
      savedByMe: result.savedByMe,
      savesCount: result.savesCount,
    );
    return result.savedByMe ? 'Saved Vibe.' : 'Removed from saved Vibes.';
  }

  Future<String?> shareVibe() async {
    if (!state.hasBackendId) return null;
    final result = await _api.shareVibe(
      state.vibe.id,
      shareChannel: 'detail',
    );
    state = state.copyWith(sharesCount: result.sharesCount);
    return 'Vibe shared.';
  }

  Future<String?> sendComment(String text) async {
    if (!state.canComment) return 'Comments are off for this Vibe.';
    final clean = text.trim();
    if (clean.isEmpty || state.sendingComment) return null;
    if (!state.hasBackendId) {
      return 'Refresh feed and open this Vibe again.';
    }

    final parentCommentId =
        state.replyingTo?.parentCommentId ?? state.replyingTo?.id;
    state = state.copyWith(sendingComment: true);
    try {
      final comment = await _api.addComment(
        state.vibe.id,
        clean,
        parentCommentId: parentCommentId,
      );
      state = state.copyWith(
        comments: _sorted(<VibeComment>[...state.comments, comment]),
        commentsCount: state.commentsCount + 1,
        replyingTo: null,
      );
      _args.onCommentChanged?.call();
      return null;
    } finally {
      state = state.copyWith(sendingComment: false);
    }
  }

  Future<void> toggleCommentLike(VibeComment comment) async {
    if (!state.hasBackendId || comment.id.trim().isEmpty) return;
    final result = await _api.toggleCommentLike(
      state.vibe.id,
      comment.id,
    );
    final next = List<VibeComment>.of(state.comments);
    final index =
        next.indexWhere((item) => item.id == result.commentId);
    if (index >= 0) {
      next[index] = next[index].copyWith(
        likedByMe: result.likedByMe,
        likesCount: result.likesCount,
      );
      state = state.copyWith(comments: next);
    }
  }

  void startReply(VibeComment comment) {
    state = state.copyWith(replyingTo: comment);
  }

  void cancelReply() {
    state = state.copyWith(replyingTo: null);
  }

  Future<String?> toggleCommentPin(VibeComment comment) async {
    if (!state.hasBackendId ||
        !comment.canPin ||
        comment.id.trim().isEmpty) {
      return null;
    }
    final isPinned = await _api.toggleCommentPin(
      state.vibe.id,
      comment.id,
    );
    final next = List<VibeComment>.of(state.comments);
    final index = next.indexWhere((item) => item.id == comment.id);
    if (index >= 0) {
      next[index] = next[index].copyWith(isPinned: isPinned);
      state = state.copyWith(comments: _sorted(next));
    }
    return isPinned ? 'Comment pinned.' : 'Comment unpinned.';
  }

  Future<String?> deleteComment(VibeComment comment) async {
    if (!state.hasBackendId ||
        !comment.canDelete ||
        comment.id.trim().isEmpty) {
      return null;
    }
    await _api.deleteComment(state.vibe.id, comment.id);
    final next = state.comments
        .where(
          (item) =>
              item.id != comment.id &&
              item.parentCommentId != comment.id,
        )
        .toList(growable: false);
    final removed = state.comments.length - next.length;
    state = state.copyWith(
      comments: next,
      commentsCount:
          (state.commentsCount - removed).clamp(0, 1 << 31),
    );
    _args.onCommentChanged?.call();
    return 'Comment deleted.';
  }

  Future<String?> deleteVibe() async {
    if (!state.isSelfVibe || state.deleting) return null;
    state = state.copyWith(deleting: true);
    try {
      await _args.onDeleteVibe?.call();
      return 'Vibe deleted.';
    } finally {
      state = state.copyWith(deleting: false);
    }
  }
}

final vibeDetailControllerProvider =
    NotifierProvider.autoDispose.family<
      VibeDetailController,
      VibeDetailState,
      VibeDetailArgs
    >(VibeDetailController.new);
