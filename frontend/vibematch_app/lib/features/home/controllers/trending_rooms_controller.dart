import 'package:flutter/foundation.dart';

import '../models/home_room_model.dart';

class TrendingRoomsController extends ChangeNotifier {
  TrendingRoomsController({
    required List<HomeRoomModel> allRooms,
    this.pageSize = 6,
    this.nextPageSize = 4,
  }) : _allRooms = List.unmodifiable(allRooms);

  final List<HomeRoomModel> _allRooms;
  final int pageSize;
  final int nextPageSize;

  int _visibleCount = 6;
  bool _isLoadingMore = false;
  List<HomeRoomModel> _filteredRooms = const [];

  int get visibleCount => _visibleCount;
  bool get isLoadingMore => _isLoadingMore;
  List<HomeRoomModel> get filteredRooms => _filteredRooms;
  List<HomeRoomModel> get visibleRooms =>
      _filteredRooms.take(_visibleCount.clamp(0, _filteredRooms.length)).toList(growable: false);
  bool get hasMore => _visibleCount < _filteredRooms.length;

  void applyFilters({
    required String category,
    required String language,
  }) {
    final source = category == 'Following'
        ? _allRooms
            .where((room) => room.followedFriendsInside.isNotEmpty && !room.isHiddenMode)
            .toList(growable: false)
        : _allRooms.where((room) => room.isPublicOpen).toList(growable: false);

    final rooms = source.where((room) {
      final categoryMatch =
          category == 'Trending' || category == 'Following' || room.type == category;
      final languageMatch = language == 'All' || room.language == language;
      return categoryMatch && languageMatch;
    }).toList(growable: false);

    rooms.sort((a, b) => b.trendingScore.compareTo(a.trendingScore));

    _filteredRooms = rooms;
    _visibleCount = pageSize.clamp(0, rooms.length);
    notifyListeners();
  }

  void loadMoreIfNeeded({required double pixels, required double maxScrollExtent}) {
    final nearBottom = pixels > maxScrollExtent - 420;
    if (!nearBottom || !hasMore || _isLoadingMore) return;

    _isLoadingMore = true;
    _visibleCount = (_visibleCount + nextPageSize).clamp(0, _filteredRooms.length);
    _isLoadingMore = false;
    notifyListeners();
  }

  void showAll() {
    _visibleCount = _filteredRooms.length;
    notifyListeners();
  }
}
