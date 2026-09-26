import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store_api_service.dart';
import '../models/store_models.dart';

const Object _storeUnset = Object();

class StoreState {
  const StoreState({
    required this.catalog,
    this.selectedCategory,
    this.isLoading = false,
    this.isPurchasing = false,
    this.errorMessage,
  });

  factory StoreState.initial() => StoreState(catalog: StoreCatalog.empty);

  final StoreCatalog catalog;
  final String? selectedCategory;
  final bool isLoading;
  final bool isPurchasing;
  final String? errorMessage;

  List<String> get categories => catalog.categories;

  List<StoreItem> get currentItems {
    final category = selectedCategory;
    if (category == null || category.isEmpty) return const <StoreItem>[];
    return catalog.sections[category] ?? const <StoreItem>[];
  }

  StoreState copyWith({
    StoreCatalog? catalog,
    Object? selectedCategory = _storeUnset,
    bool? isLoading,
    bool? isPurchasing,
    Object? errorMessage = _storeUnset,
  }) {
    return StoreState(
      catalog: catalog ?? this.catalog,
      selectedCategory: identical(selectedCategory, _storeUnset)
          ? this.selectedCategory
          : selectedCategory as String?,
      isLoading: isLoading ?? this.isLoading,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      errorMessage: identical(errorMessage, _storeUnset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class StoreController extends AutoDisposeNotifier<StoreState> {
  final StoreApiService _api = const StoreApiService();

  @override
  StoreState build() => StoreState.initial();

  Future<void> load() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final catalog = await _api.fetchCatalog();
      final selected = catalog.categories.contains(state.selectedCategory)
          ? state.selectedCategory
          : (catalog.categories.isEmpty ? null : catalog.categories.first);
      state = state.copyWith(
        catalog: catalog,
        selectedCategory: selected,
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(
        catalog: StoreCatalog.empty,
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

  Future<String> purchase(StoreItem item) async {
    if (state.isPurchasing) return 'Purchase already in progress';
    state = state.copyWith(isPurchasing: true);
    try {
      final updated = await _api.purchase(item.itemId);
      final existing =
          state.catalog.sections[updated.category] ?? const <StoreItem>[];
      final replaced = existing
          .map((entry) => entry.itemId == updated.itemId ? updated : entry)
          .toList(growable: false);
      state = state.copyWith(
        catalog: StoreCatalog(
          categories: state.catalog.categories,
          sections: <String, List<StoreItem>>{
            ...state.catalog.sections,
            updated.category: replaced,
          },
        ),
      );
      return updated.isOwned
          ? '${updated.name} purchased'
          : '${updated.name} updated';
    } finally {
      state = state.copyWith(isPurchasing: false);
    }
  }
}

final storeControllerProvider =
    NotifierProvider.autoDispose<StoreController, StoreState>(
      StoreController.new,
    );
