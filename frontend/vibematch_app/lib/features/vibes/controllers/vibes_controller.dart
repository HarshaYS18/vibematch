import 'package:flutter/foundation.dart';

import '../data/vibes_api_service.dart';
import '../models/vibe_models.dart';

class VibesController extends ChangeNotifier {
  VibesController({VibesApiService? apiService}) : _apiService = apiService ?? const VibesApiService();

  final VibesApiService _apiService;

  String selectedFilter = 'All';
  VibePrivacyAudience whoCanMention = VibePrivacyAudience.followers;
  VibePrivacyAudience whoCanComment = VibePrivacyAudience.followers;
  int mentionAllPostsToday = 0;
  bool isLoading = false;
  String? loadErrorMessage;

  final List<String> filters = const [
    'All',
    'Following',
    'Photos',
    'Videos',
    'Mentions',
    'Trending',
  ];

  final List<VibeItem> _vibes = <VibeItem>[];

  List<VibeItem> get vibes => List.unmodifiable(_vibes);

  List<VibeItem> get visibleVibes {
    if (selectedFilter == 'Following') {
      return _vibes.where((vibe) => vibe.isFollowing).toList();
    }
    if (selectedFilter == 'Photos') {
      return _vibes.where((vibe) => vibe.mediaType == VibeMediaType.photo).toList();
    }
    if (selectedFilter == 'Videos') {
      return _vibes.where((vibe) => vibe.mediaType == VibeMediaType.video).toList();
    }
    if (selectedFilter == 'Mentions') {
      return _vibes.where((vibe) => vibe.usesMentionAll || vibe.mentions.isNotEmpty).toList();
    }
    if (selectedFilter == 'Trending') {
      final sorted = [..._vibes]..sort((a, b) => b.views.compareTo(a.views));
      return sorted;
    }
    return _vibes;
  }

  bool get canUseMentionAllToday => mentionAllPostsToday < 2;

  Future<void> loadFeed({bool silent = false}) async {
    if (isLoading) return;
    isLoading = true;
    if (!silent) loadErrorMessage = null;
    notifyListeners();
    try {
      final backendVibes = await _apiService.loadFeed(limit: 50);
      _vibes
        ..clear()
        ..addAll(backendVibes);
      loadErrorMessage = null;
    } catch (error) {
      loadErrorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectFilter(String filter) {
    selectedFilter = filter;
    notifyListeners();
  }

  void setWhoCanMention(VibePrivacyAudience audience) {
    whoCanMention = audience;
    notifyListeners();
  }

  void setWhoCanComment(VibePrivacyAudience audience) {
    whoCanComment = audience;
    notifyListeners();
  }

  bool isValidMentionToken(String token) {
    final clean = token.trim();
    if (clean == '@all') return canUseMentionAllToday;
    if (!clean.startsWith('@')) return false;
    final username = clean.substring(1);
    if (username.length < 2 || username.length > 32) return false;
    return RegExp(r'^[a-zA-Z0-9_\.]+$').hasMatch(username);
  }

  Future<void> publishVibe(VibeItem vibe) async {
    final created = await _apiService.createVibe(vibe);
    if (created.usesMentionAll) mentionAllPostsToday += 1;
    _vibes.insert(0, created);
    selectedFilter = 'All';
    notifyListeners();
  }

  Future<void> deleteVibe(VibeItem vibe) async {
    if (vibe.id.trim().isEmpty) {
      throw Exception('Cannot delete an unsynced Vibe. Refresh and try again.');
    }
    await _apiService.deleteVibe(vibe.id);
    _vibes.removeWhere((item) => item.id == vibe.id && item.authorId == vibe.authorId);
    notifyListeners();
  }

  Future<void> toggleLike(VibeItem vibe) async {
    final index = _vibes.indexOf(vibe);
    if (index < 0) return;
    if (vibe.id.trim().isEmpty) {
      throw Exception('Vibe is not synced yet. Refresh and try again.');
    }
    final result = await _apiService.toggleLike(vibe.id);
    _vibes[index] = vibe.copyWith(likedByMe: result.likedByMe, likes: result.likesCount);
    notifyListeners();
  }

  Future<void> shareVibe(VibeItem vibe, {int? targetPublicUserId}) async {
    final index = _vibes.indexOf(vibe);
    if (index < 0) return;
    if (vibe.id.trim().isEmpty) {
      throw Exception('Vibe is not synced yet. Refresh and try again.');
    }
    final result = await _apiService.shareVibe(vibe.id, targetPublicUserId: targetPublicUserId);
    _vibes[index] = vibe.copyWith(shares: result.sharesCount);
    notifyListeners();
  }

  Future<void> reportVibe(VibeItem vibe, {required String reason, String? details}) async {
    if (vibe.id.trim().isEmpty) {
      throw Exception('Vibe is not synced yet. Refresh and try again.');
    }
    await _apiService.reportVibe(vibe.id, reason: reason, details: details);
  }

  void incrementCommentCount(VibeItem vibe) {
    final index = _vibes.indexOf(vibe);
    if (index < 0) return;
    _vibes[index] = vibe.copyWith(comments: vibe.comments + 1);
    notifyListeners();
  }
}
