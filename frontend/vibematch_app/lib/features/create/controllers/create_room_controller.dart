import 'package:flutter/foundation.dart';

import '../models/create_room_mode.dart';

class CreateRoomController extends ChangeNotifier {
  CreateRoomController();

  static const languages = <String>[
    'Telugu',
    'Hindi',
    'English',
    'Tamil',
    'Malayalam',
    'Kannada',
    'Bengali',
    'Marathi',
    'Punjabi',
    'Gujarati',
    'Odia',
    'Urdu',
    'Arabic',
    'Spanish',
    'French',
    'Other',
  ];

  String _selectedLanguage = 'Telugu';
  CreateRoomMode _selectedMode = CreateRoomMode.open;
  bool _roomImageSelected = false;

  String get selectedLanguage => _selectedLanguage;
  CreateRoomMode get selectedMode => _selectedMode;
  bool get roomImageSelected => _roomImageSelected;

  void selectLanguage(String language) {
    if (language == _selectedLanguage) return;
    _selectedLanguage = language;
    notifyListeners();
  }

  void selectMode(CreateRoomMode mode) {
    if (mode == _selectedMode) return;
    _selectedMode = mode;
    notifyListeners();
  }

  bool toggleRoomImage() {
    _roomImageSelected = !_roomImageSelected;
    notifyListeners();
    return _roomImageSelected;
  }

  String generateRoomId() {
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    return 'VM${now.substring(now.length - 6)}';
  }
}
