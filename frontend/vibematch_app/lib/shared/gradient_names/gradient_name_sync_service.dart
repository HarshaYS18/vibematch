import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../foundation/di/app_dependencies.dart';
import 'gradient_name_style.dart';

/// Riverpod owner for the current user's equipped store gradient-name style.
///
/// Source of truth: the persisted canonical inventory payload written under
/// [inventoryKey]. This controller owns no process-global mutable notifier and
/// is invalidated after inventory equipment changes. Consumers should read
/// [equippedGradientNameStyleProvider] instead of caching a second copy.
class GradientNameSyncController extends AsyncNotifier<GradientNameStyle?> {
  static const String inventoryKey = 'vm_store.inventory';

  @override
  Future<GradientNameStyle?> build() async {
    final store = await ref.watch(appKeyValueStoreProvider.future);
    return resolveEquippedGradient(store.readString(inventoryKey));
  }

  /// Re-reads the persisted inventory after an external inventory mutation.
  Future<void> refreshFromStorage() async {
    state = const AsyncLoading<GradientNameStyle?>();
    state = await AsyncValue.guard(() async {
      final store = await ref.read(appKeyValueStoreProvider.future);
      return resolveEquippedGradient(store.readString(inventoryKey));
    });
  }

  /// Resolves the most recent non-expired equipped gradient-name inventory item.
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
          if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
            continue;
          }
        }

        final styleId = itemId
            .replaceFirst('gradient_name_', '')
            .replaceFirst('_30d', '');
        final style = GradientNameStyle.byId(styleId);
        if (style.id != GradientNameStyle.defaultName.id) return style;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

/// App-scope provider for equipped gradient-name presentation state.
///
/// It is intentionally non-auto-dispose because the equipped identity style is
/// session-wide UI state reused across profile, room and social surfaces.
final equippedGradientNameStyleProvider =
    AsyncNotifierProvider<GradientNameSyncController, GradientNameStyle?>(
      GradientNameSyncController.new,
    );
