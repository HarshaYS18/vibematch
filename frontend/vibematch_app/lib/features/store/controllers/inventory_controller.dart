import 'package:flutter/foundation.dart';

import '../data/store_api_service.dart';
import '../models/store_models.dart';

class InventoryController extends ChangeNotifier {
  InventoryController({StoreApiService? api}) : _api = api ?? const StoreApiService();

  final StoreApiService _api;

  UserInventory inventory = UserInventory.empty;
  String? selectedCategory;
  bool isLoading = false;
  bool isUpdating = false;
  String? errorMessage;

  List<String> get categories => inventory.categories;

  List<InventoryItem> get currentItems {
    final category = selectedCategory;
    if (category == null || category.isEmpty) return const <InventoryItem>[];
    return inventory.sections[category] ?? const <InventoryItem>[];
  }

  Future<void> load() async {
    if (isLoading) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      inventory = await _api.fetchInventory();
      selectedCategory = inventory.categories.contains(selectedCategory) ? selectedCategory : (inventory.categories.isEmpty ? null : inventory.categories.first);
    } catch (error) {
      inventory = UserInventory.empty;
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

  Future<String> equip(InventoryItem item) async {
    if (isUpdating) return 'Update already in progress';
    isUpdating = true;
    notifyListeners();
    try {
      final updated = await _api.equip(itemId: item.itemId, equipped: !item.isEquipped);
      await load();
      return updated.isEquipped ? '${updated.name} equipped' : '${updated.name} unequipped';
    } finally {
      isUpdating = false;
      notifyListeners();
    }
  }
}
