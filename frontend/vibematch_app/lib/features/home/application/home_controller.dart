import 'package:flutter/foundation.dart';

import '../data/home_mock_data.dart';
import '../models/home_banner_data.dart';
import '../models/home_room_data.dart';

class HomeController extends ChangeNotifier {
  int selectedBannerIndex = 0;
  int visibleRoomCount = 6;
  String selectedCategory = 'Trending';
  String selectedLanguage = 'All';
  HomeRoomData? myCreatedRoom;

  List<String> get categories => HomeMockData.categories;
  List<String> get languages => HomeMockData.languages;
  List<HomeBannerData> get banners => HomeMockData.banners;

  bool get hasCreatedRoom => myCreatedRoom != null;

  List<HomeRoomData> get publicOpenRooms {
    return HomeMockData.rooms.where((room) => room.isPublicOpen).toList();
  }

  List<HomeRoomData> get followingExceptionRooms {
    return HomeMockData.rooms.where((room) {
      return room.followedFriendsInside.isNotEmpty && !room.isSecretVibe;
    }).toList();
  }

  List<HomeRoomData> get filteredRooms {
    final sourceRooms = selectedCategory == 'Following'
        ? followingExceptionRooms
        : publicOpenRooms;

    final filtered = sourceRooms.where((room) {
      final categoryMatch = selectedCategory == 'Trending' ||
          selectedCategory == 'Following' ||
          room.type == selectedCategory;

      final languageMatch = selectedLanguage == 'All' ||
          room.language == selectedLanguage;

      return categoryMatch && languageMatch;
    }).toList();

    filtered.sort((a, b) => b.trendingScore.compareTo(a.trendingScore));
    return filtered;
  }

  List<HomeRoomData> get visibleRooms {
    final rooms = filteredRooms;
    return rooms.take(visibleRoomCount.clamp(0, rooms.length)).toList();
  }

  void setBannerIndex(int index) {
    selectedBannerIndex = index;
    notifyListeners();
  }

  void selectCategory(String category) {
    selectedCategory = category;
    visibleRoomCount = 6;
    notifyListeners();
  }

  void selectLanguage(String language) {
    selectedLanguage = language;
    visibleRoomCount = 6;
    notifyListeners();
  }

  void revealMoreRooms({int increment = 4}) {
    if (visibleRoomCount >= filteredRooms.length) return;
    visibleRoomCount = (visibleRoomCount + increment).clamp(0, filteredRooms.length);
    notifyListeners();
  }

  void showAllRooms() {
    visibleRoomCount = filteredRooms.length;
    notifyListeners();
  }

  void setMyCreatedRoom(HomeRoomData room) {
    myCreatedRoom = room;
    notifyListeners();
  }
}
