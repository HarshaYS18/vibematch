import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gradient_name_style.dart';

class GradientNameSyncService {
  const GradientNameSyncService._();

  static const String inventoryKey = 'vm_store.inventory';

  static final ValueNotifier<GradientNameStyle?> equippedStyle =
      ValueNotifier<GradientNameStyle?>(null);

  static bool _loadedOnce = false;
  static bool _loading = false;

  static Future<void> ensureLoaded() async {
    if (_loadedOnce || _loading) return;
    await refreshFromStorage();
  }

  static Future<void> refreshFromStorage() async {
    if (_loading) return;
    _loading = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      equippedStyle.value = resolveEquippedGradient(prefs.getString(inventoryKey));
      _loadedOnce = true;
    } finally {
      _loading = false;
    }
  }

  static Future<void> clearEquippedStyle() async {
    equippedStyle.value = null;
    await refreshFromStorage();
  }

  static GradientNameStyle? resolveEquippedGradient(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      for (final item in decoded.reversed) {
        if (item is! Map) continue;
        final entry = Map<String, dynamic>.from(item);
        final itemId = entry['item_id']?.toString() ?? '';
        final equipped = entry['is_equipped'] == true;
        if (!equipped || !itemId.startsWith('gradient_name_')) continue;
        final expiresRaw = entry['expires_at']?.toString();
        if (expiresRaw != null && expiresRaw.trim().isNotEmpty) {
          final expiresAt = DateTime.tryParse(expiresRaw);
          if (expiresAt != null && DateTime.now().isAfter(expiresAt)) continue;
        }
        final styleId = itemId.replaceFirst('gradient_name_', '').replaceFirst('_30d', '');
        final style = GradientNameStyle.byId(styleId);
        if (style.id != GradientNameStyle.defaultName.id) return style;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
