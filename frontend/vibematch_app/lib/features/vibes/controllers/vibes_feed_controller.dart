import 'package:flutter/foundation.dart';

import '../models/vibe_item.dart';
import '../models/vibe_media_type.dart';

class VibesFeedController extends ChangeNotifier {
  VibesFeedController({
    required List<VibeItem> initialVibes,
    this.initialVisibleCount = 6,
    this.nextPageSize = 4,
  })  : _vibes = List<VibeItem>.from(initialVibes),
        _visibleCount = initialVisibleCount;

  final int initialVisibleCount;
  final int nextPageSize;

  final List<VibeItem> _vibes;
  String _selectedFilter = 'All';
  int _visibleCount;

  String get selectedFilter => _selectedFilter;
  List<VibeItem> get allVibes => List.unmodifiable(_vibes);

  List<VibeItem> get filteredVibes {
    if (_selectedFilter == 'Following') {
      return _vibes.where((vibe) => vibe.isFollowing).toList(growable: false);
    }

    if (_selectedFilter == 'Photos') {
      return _vibes
          .where((vibe) => vibe.mediaType == VibeMediaType.photo)
          .toList(growable: false);
    }

    if (_selectedFilter == 'Videos') {
      return _vibes
          .where((vibe) => vibe.mediaType == VibeMediaType.video)
          .toList(growable: false);
    }

    if (_selectedFilter == 'Mentions') {
      return _vibes
          .where((vibe) => vibe.usesMentionAll || vibe.mentions.isNotEmpty)
          .toList(growable: false);
    }

    if (_selectedFilter == 'Trending') {
      final sorted = List<VibeItem>.from(_vibes);
      sorted.sort((a, b) => b.views.compareTo(a.views));
      return sorted;
    }

    return List.unmodifiable(_vibes);
  }

  List<VibeItem> get visibleVibes {
    final filtered = filteredVibes;
    return filtered.take(_visibleCount.clamp(0, filtered.length)).toList(growable: false);
  }

  bool get hasMore => _visibleCount < filteredVibes.length;

  void selectFilter(String filter) {
    if (filter == _selectedFilter) return;
    _selectedFilter = filter;
    _visibleCount = initialVisibleCount;
    notifyListeners();
  }

  void publishLocalVibe(VibeItem vibe) {
    _vibes.insert(0, vibe);
    _selectedFilter = 'All';
    _visibleCount = initialVisibleCount;
    notifyListeners();
  }

  void likeVibe(VibeItem vibe) {
    final index = _vibes.indexOf(vibe);
    if (index == -1) return;
    _vibes[index] = vibe.copyWith(likes: vibe.likes + 1);
    notifyListeners();
  }

  void loadMoreIfNeeded({required double pixels, required double maxScrollExtent}) {
    final nearBottom = pixels > maxScrollExtent - 420;
    if (!nearBottom || !hasMore) return;
    _visibleCount = (_visibleCount + nextPageSize).clamp(0, filteredVibes.length);
    notifyListeners();
  }
}
