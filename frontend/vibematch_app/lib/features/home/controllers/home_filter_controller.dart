import 'package:flutter/foundation.dart';

class HomeFilterController extends ChangeNotifier {
  HomeFilterController({
    required List<String> languages,
    required String initialCategory,
    required String initialLanguage,
  })  : _languages = List.unmodifiable(languages),
        _selectedCategory = initialCategory,
        _selectedLanguage = initialLanguage;

  final List<String> _languages;
  String _selectedCategory;
  String _selectedLanguage;

  List<String> get languages => _languages;
  String get selectedCategory => _selectedCategory;
  String get selectedLanguage => _selectedLanguage;

  void selectCategory(String value) {
    if (value == _selectedCategory) return;
    _selectedCategory = value;
    notifyListeners();
  }

  void selectLanguage(String value) {
    if (value == _selectedLanguage) return;
    _selectedLanguage = value;
    notifyListeners();
  }
}
