import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'store_catalog.dart';
import 'store_models.dart';

class VmStoreRepository {
  const VmStoreRepository._();

  static const String _coinBalanceKey = 'vm_store.coin_balance';
  static const String _hasLoveRelationshipKey = 'vm_store.has_love_relationship';
  static const String _inventoryKey = 'vm_store.inventory';

  static Future<VmStoreUserState> loadUserState() async {
    final prefs = await SharedPreferences.getInstance();
    final rawInventory = prefs.getString(_inventoryKey);
    final inventory = _decodeInventory(rawInventory);

    return VmStoreUserState(
      coinBalance: prefs.getInt(_coinBalanceKey) ?? 125000,
      hasLoveRelationship: prefs.getBool(_hasLoveRelationshipKey) ?? false,
      inventory: inventory,
    );
  }

  static Future<List<VmStoreItem>> loadCatalog({required bool hasLoveRelationship}) async {
    // Backend-ready boundary: later replace this with GET /store/catalog.
    // Items carry remote asset keys so assets can be updated from CDN/config without app updates.
    return VmStoreCatalog.visibleStoreItems(hasLoveRelationship: hasLoveRelationship);
  }

  static Future<VmStoreUserState> buyItem(VmStoreUserState state, VmStoreItem item) async {
    if (state.owns(item.id)) {
      throw StateError('You already own this item.');
    }
    if (item.type == VmStoreItemType.loveCard && state.hasLoveRelationship) {
      throw StateError('Love Card is unavailable because you already have a Lover bond.');
    }
    if (item.maxOwnable != null && _ownedCount(state, item.id) >= item.maxOwnable!) {
      throw StateError('Maximum ownership limit reached.');
    }
    if (state.coinBalance < item.priceCoins) {
      throw StateError('Not enough coins.');
    }

    final now = DateTime.now();
    final entry = VmStoreInventoryEntry(
      itemId: item.id,
      ownedAt: now,
      expiresAt: item.durationDays == null ? null : now.add(Duration(days: item.durationDays!)),
    );

    final next = state.copyWith(
      coinBalance: state.coinBalance - item.priceCoins,
      inventory: <VmStoreInventoryEntry>[...state.inventory, entry],
    );
    await saveUserState(next);
    return next;
  }

  static Future<VmStoreUserState> equipItem(VmStoreUserState state, VmStoreItem item) async {
    if (!state.owns(item.id)) {
      throw StateError('You need to own this item before equipping it.');
    }

    final nextInventory = state.inventory.map((entry) {
      if (entry.isExpired) return entry.copyWith(isEquipped: false);
      if (entry.itemId == item.id) return entry.copyWith(isEquipped: true);
      final entryItem = _findCatalogItem(entry.itemId);
      if (entryItem != null && entryItem.section == item.section) return entry.copyWith(isEquipped: false);
      return entry;
    }).toList();

    final next = state.copyWith(inventory: nextInventory);
    await saveUserState(next);
    return next;
  }

  static Future<VmStoreUserState> unequipItem(VmStoreUserState state, VmStoreItem item) async {
    final nextInventory = state.inventory.map((entry) {
      if (entry.itemId == item.id) return entry.copyWith(isEquipped: false);
      return entry;
    }).toList();

    final next = state.copyWith(inventory: nextInventory);
    await saveUserState(next);
    return next;
  }

  static Future<VmStoreUserState> toggleLoveRelationshipForDebug(VmStoreUserState state) async {
    final next = state.copyWith(hasLoveRelationship: !state.hasLoveRelationship);
    await saveUserState(next);
    return next;
  }

  static Future<void> saveUserState(VmStoreUserState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_coinBalanceKey, state.coinBalance);
    await prefs.setBool(_hasLoveRelationshipKey, state.hasLoveRelationship);
    await prefs.setString(_inventoryKey, jsonEncode(state.inventory.map((entry) => entry.toJson()).toList()));
  }

  static VmStoreItem? _findCatalogItem(String itemId) {
    for (final item in VmStoreCatalog.dynamicItems) {
      if (item.id == itemId) return item;
    }
    return null;
  }

  static int _ownedCount(VmStoreUserState state, String itemId) {
    return state.inventory.where((entry) => !entry.isExpired && entry.itemId == itemId).length;
  }

  static List<VmStoreInventoryEntry> _decodeInventory(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <VmStoreInventoryEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <VmStoreInventoryEntry>[];
      return decoded
          .whereType<Map>()
          .map((item) => VmStoreInventoryEntry.fromJson(Map<String, dynamic>.from(item)))
          .where((entry) => entry.itemId.isNotEmpty)
          .toList();
    } catch (_) {
      return <VmStoreInventoryEntry>[];
    }
  }
}
