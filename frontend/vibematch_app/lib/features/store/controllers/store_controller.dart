import 'package:flutter/foundation.dart';

import '../data/store_api_service.dart';
import '../models/store_models.dart';

class StoreController extends ChangeNotifier {
  StoreController({StoreApiService? api}) : _api = api ?? const StoreApiService();

  final StoreApiService _api;

  StoreCatalog catalog = StoreCatalog.empty;
  String? selectedCategory;
  bool isLoading = false;
  bool isPurchasing = false;
  String? errorMessage;

  List<String> get categories => catalog.categories;

  List<StoreItem> get currentItems {
    final category = selectedCategory;
    if (category == null || category.isEmpty) return const <StoreItem>[];
    return catalog.sections[category] ?? const <StoreItem>[];
  }

  Future<void> load() async {
    if (isLoading) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      catalog = await _api.fetchCatalog();
      selectedCategory = catalog.categories.contains(selectedCategory) ? selectedCategory : (catalog.categories.isEmpty ? null : catalog.categories.first);
    } catch (error) {
      catalog = StoreCatalog.empty;
      selectedCategory = null;
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectCategory(String category) {
    if (selectedCategory == category) return;
    selectedCategory = category;
    notifyListeners();
  }

  Future<String> purchase(StoreItem item) async {
    if (isPurchasing) return 'Purchase already in progress';
    isPurchasing = true;
    notifyListeners();
    try {
      final updated = await _api.purchase(item.itemId);
      _replaceItem(updated);
      return updated.isOwned ? '${updated.name} purchased' : '${updated.name} updated';
    } finally {
      isPurchasing = false;
      notifyListeners();
    }
  }

  void _replaceItem(StoreItem updated) {
    final existingItems = catalog.sections[updated.category] ?? const <StoreItem>[];
    final replaced = existingItems.map((item) => item.itemId == updated.itemId ? updated : item).toList(growable: false);
    catalog = StoreCatalog(categories: catalog.categories, sections: {...catalog.sections, updated.category: replaced});
  }
}
