import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/vibes_api_service.dart';
import '../models/vibe_models.dart';

const Object _vibesUnset = Object();

class VibesState {
  const VibesState({
    this.selectedTab = VibesFeedTab.vibes,
    this.whoCanMention = VibePrivacyAudience.followers,
    this.whoCanComment = VibePrivacyAudience.followers,
    this.mentionAllPostsToday = 0,
    this.isLoading = false,
    this.showingSavedVibes = false,
    this.loadErrorMessage,
    this.vibes = const <VibeItem>[],
  });

  final VibesFeedTab selectedTab;
  final VibePrivacyAudience whoCanMention;
  final VibePrivacyAudience whoCanComment;
  final int mentionAllPostsToday;
  final bool isLoading;
  final bool showingSavedVibes;
  final String? loadErrorMessage;
  final List<VibeItem> vibes;

  List<VibeItem> get visibleVibes => vibes;
  bool get canUseMentionAllToday => mentionAllPostsToday < 2;

  VibesState copyWith({
    VibesFeedTab? selectedTab,
    VibePrivacyAudience? whoCanMention,
    VibePrivacyAudience? whoCanComment,
    int? mentionAllPostsToday,
    bool? isLoading,
    bool? showingSavedVibes,
    Object? loadErrorMessage = _vibesUnset,
    List<VibeItem>? vibes,
  }) {
    return VibesState(
      selectedTab: selectedTab ?? this.selectedTab,
      whoCanMention: whoCanMention ?? this.whoCanMention,
      whoCanComment: whoCanComment ?? this.whoCanComment,
      mentionAllPostsToday:
          mentionAllPostsToday ?? this.mentionAllPostsToday,
      isLoading: isLoading ?? this.isLoading,
      showingSavedVibes: showingSavedVibes ?? this.showingSavedVibes,
      loadErrorMessage: identical(loadErrorMessage, _vibesUnset)
          ? this.loadErrorMessage
          : loadErrorMessage as String?,
      vibes: List<VibeItem>.unmodifiable(vibes ?? this.vibes),
    );
  }
}

class VibesController extends AutoDisposeNotifier<VibesState> {
  final VibesApiService _apiService = const VibesApiService();

  VibesFeedTab get selectedTab => state.selectedTab;
  VibePrivacyAudience get whoCanMention => state.whoCanMention;
  VibePrivacyAudience get whoCanComment => state.whoCanComment;
  bool get canUseMentionAllToday => state.canUseMentionAllToday;
  bool get showingSavedVibes => state.showingSavedVibes;
  bool get isLoading => state.isLoading;
  String? get loadErrorMessage => state.loadErrorMessage;
  List<VibeItem> get visibleVibes => state.visibleVibes;

  @override
  VibesState build() => const VibesState();

  Future<void> loadFeed({bool silent = false}) async {
    if (state.isLoading) return;
    state = state.copyWith(
      isLoading: true,
      showingSavedVibes: false,
      loadErrorMessage: silent ? state.loadErrorMessage : null,
    );
    try {
      final backendVibes = await _apiService.loadFeed(
        limit: 50,
        tab: state.selectedTab,
      );
      state = state.copyWith(
        vibes: backendVibes,
        loadErrorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(
        vibes: const <VibeItem>[],
        loadErrorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadSavedVibes() async {
    if (state.isLoading) return;
    state = state.copyWith(
      isLoading: true,
      showingSavedVibes: true,
      loadErrorMessage: null,
    );
    try {
      state = state.copyWith(
        vibes: await _apiService.loadSavedVibes(limit: 50),
        loadErrorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(
        vibes: const <VibeItem>[],
        loadErrorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void selectTab(VibesFeedTab tab) {
    if (state.selectedTab == tab && !state.showingSavedVibes) return;
    state = state.copyWith(
      selectedTab: tab,
      showingSavedVibes: false,
      vibes: const <VibeItem>[],
    );
    loadFeed();
  }

  void setWhoCanMention(VibePrivacyAudience audience) {
    state = state.copyWith(whoCanMention: audience);
  }

  void setWhoCanComment(VibePrivacyAudience audience) {
    state = state.copyWith(whoCanComment: audience);
  }

  bool isValidMentionToken(String token) {
    final clean = token.trim();
    if (clean == '@all') return state.canUseMentionAllToday;
    if (!clean.startsWith('@')) return false;
    final username = clean.substring(1);
    if (username.length < 2 || username.length > 32) return false;
    return RegExp(r'^[a-zA-Z0-9_\.]+$').hasMatch(username);
  }

  Future<void> publishVibe(VibeItem vibe) async {
    final created = await _apiService.createVibe(vibe);
    final nextMentionCount = state.mentionAllPostsToday +
        (created.usesMentionAll ? 1 : 0);
    if (state.selectedTab == VibesFeedTab.vibes) {
      state = state.copyWith(
        mentionAllPostsToday: nextMentionCount,
        showingSavedVibes: false,
        vibes: <VibeItem>[created, ...state.vibes],
      );
      return;
    }
    state = state.copyWith(
      selectedTab: VibesFeedTab.vibes,
      mentionAllPostsToday: nextMentionCount,
      showingSavedVibes: false,
      vibes: <VibeItem>[created],
    );
  }

  Future<void> deleteVibe(VibeItem vibe) async {
    if (vibe.id.trim().isEmpty) {
      throw Exception('Cannot delete an unsynced Vibe. Refresh and try again.');
    }
    await _apiService.deleteVibe(vibe.id);
    state = state.copyWith(
      vibes: state.vibes
          .where(
            (item) =>
                !(item.id == vibe.id && item.authorId == vibe.authorId),
          )
          .toList(growable: false),
    );
  }

  Future<void> toggleLike(VibeItem vibe) async {
    final index = state.vibes.indexOf(vibe);
    if (index < 0) return;
    if (vibe.id.trim().isEmpty) {
      throw Exception('Vibe is not synced yet. Refresh and try again.');
    }
    final result = await _apiService.toggleLike(vibe.id);
    final next = List<VibeItem>.of(state.vibes);
    next[index] = vibe.copyWith(
      likedByMe: result.likedByMe,
      likes: result.likesCount,
    );
    state = state.copyWith(vibes: next);
  }

  Future<void> toggleSave(VibeItem vibe) async {
    final index = state.vibes.indexOf(vibe);
    if (index < 0) return;
    if (vibe.id.trim().isEmpty) {
      throw Exception('Vibe is not synced yet. Refresh and try again.');
    }
    final result = await _apiService.toggleSave(vibe.id);
    final next = List<VibeItem>.of(state.vibes);
    next[index] = vibe.copyWith(
      savedByMe: result.savedByMe,
      saves: result.savesCount,
    );
    if (state.showingSavedVibes && !result.savedByMe) {
      next.removeWhere((item) => item.id == vibe.id);
    }
    state = state.copyWith(vibes: next);
  }

  Future<void> shareVibe(
    VibeItem vibe, {
    int? targetPublicUserId,
  }) async {
    final index = state.vibes.indexOf(vibe);
    if (index < 0) return;
    if (vibe.id.trim().isEmpty) {
      throw Exception('Vibe is not synced yet. Refresh and try again.');
    }
    final result = await _apiService.shareVibe(
      vibe.id,
      targetPublicUserId: targetPublicUserId,
    );
    final next = List<VibeItem>.of(state.vibes);
    next[index] = vibe.copyWith(shares: result.sharesCount);
    state = state.copyWith(vibes: next);
  }

  Future<void> reportVibe(
    VibeItem vibe, {
    required String reason,
    String? details,
  }) async {
    if (vibe.id.trim().isEmpty) {
      throw Exception('Vibe is not synced yet. Refresh and try again.');
    }
    await _apiService.reportVibe(
      vibe.id,
      reason: reason,
      details: details,
    );
  }

  void incrementCommentCount(VibeItem vibe) {
    final index = state.vibes.indexOf(vibe);
    if (index < 0) return;
    final next = List<VibeItem>.of(state.vibes);
    next[index] = vibe.copyWith(comments: vibe.comments + 1);
    state = state.copyWith(vibes: next);
  }
}

final vibesControllerProvider =
    NotifierProvider.autoDispose<VibesController, VibesState>(
      VibesController.new,
    );
