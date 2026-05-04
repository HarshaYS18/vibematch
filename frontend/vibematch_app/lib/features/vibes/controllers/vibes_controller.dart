import 'package:flutter/foundation.dart';

import '../../social/data/social_mock_data.dart';
import '../data/vibes_mock_data.dart';
import '../models/vibe_models.dart';

class VibesController extends ChangeNotifier {
  String selectedFilter = 'All';
  VibePrivacyAudience whoCanMention = VibePrivacyAudience.followers;
  VibePrivacyAudience whoCanComment = VibePrivacyAudience.followers;
  int mentionAllPostsToday = 0;

  final List<String> filters = const [
    'All',
    'Following',
    'Photos',
    'Videos',
    'Mentions',
    'Trending',
  ];

  final List<VibeItem> _vibes = [...VibesMockData.vibes];

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
    return SocialMockData.isValidMention(token);
  }

  void publishVibe(VibeItem vibe) {
    if (vibe.usesMentionAll) mentionAllPostsToday += 1;
    _vibes.insert(0, vibe);
    selectedFilter = 'All';
    notifyListeners();
  }

  void toggleLike(VibeItem vibe) {
    final index = _vibes.indexOf(vibe);
    if (index < 0) return;
    final liked = vibe.likedByMe;
    _vibes[index] = vibe.copyWith(
      likedByMe: !liked,
      likes: liked ? vibe.likes - 1 : vibe.likes + 1,
    );
    notifyListeners();
  }

  void incrementCommentCount(VibeItem vibe) {
    final index = _vibes.indexOf(vibe);
    if (index < 0) return;
    _vibes[index] = vibe.copyWith(comments: vibe.comments + 1);
    notifyListeners();
  }
}
