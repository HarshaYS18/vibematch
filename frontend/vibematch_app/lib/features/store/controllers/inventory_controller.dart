import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store_api_service.dart';
import '../models/store_models.dart';

const Object _inventoryUnset = Object();

class InventoryState {
  const InventoryState({
    required this.inventory,
    this.selectedCategory,
    this.isLoading = false,
    this.isUpdating = false,
    this.errorMessage,
  });

  factory InventoryState.initial() =>
      InventoryState(inventory: UserInventory.empty);

  final UserInventory inventory;
  final String? selectedCategory;
  final bool isLoading;
  final bool isUpdating;
  final String? errorMessage;

  List<String> get categories => inventory.categories;

  List<InventoryItem> get currentItems {
    final category = selectedCategory;
    if (category == null || category.isEmpty) return const <InventoryItem>[];
    return inventory.sections[category] ?? const <InventoryItem>[];
  }

  InventoryState copyWith({
    UserInventory? inventory,
    Object? selectedCategory = _inventoryUnset,
    bool? isLoading,
    bool? isUpdating,
    Object? errorMessage = _inventoryUnset,
  }) {
    return InventoryState(
      inventory: inventory ?? this.inventory,
      selectedCategory: identical(selectedCategory, _inventoryUnset)
          ? this.selectedCategory
          : selectedCategory as String?,
      isLoading: isLoading ?? this.isLoading,
      isUpdating: isUpdating ?? this.isUpdating,
      errorMessage: identical(errorMessage, _inventoryUnset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class InventoryController extends AutoDisposeNotifier<InventoryState> {
  final StoreApiService _api = const StoreApiService();

  @override
  InventoryState build() => InventoryState.initial();

  Future<void> load() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final inventory = await _api.fetchInventory();
      final selected = inventory.categories.contains(state.selectedCategory)
          ? state.selectedCategory
          : (inventory.categories.isEmpty ? null : inventory.categories.first);
      state = state.copyWith(
        inventory: inventory,
        selectedCategory: selected,
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(
        inventory: UserInventory.empty,
        selectedCategory: null,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void selectCategory(String category) {
    if (state.selectedCategory == category) return;
    state = state.copyWith(selectedCategory: category);
  }

  Future<String> equip(InventoryItem item) async {
    if (state.isUpdating) return 'Update already in progress';
    state = state.copyWith(isUpdating: true);
    try {
      final updated = await _api.equip(
        itemId: item.itemId,
        equipped: !item.isEquipped,
      );
      await load();
      return updated.isEquipped
          ? '${updated.name} equipped'
          : '${updated.name} unequipped';
    } finally {
      state = state.copyWith(isUpdating: false);
    }
  }
}

final inventoryControllerProvider =
    NotifierProvider.autoDispose<InventoryController, InventoryState>(
      InventoryController.new,
    );
