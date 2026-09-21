import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../presentation/live_room_models.dart';
import '../presentation/widgets/gift_modules/gift_panel_constants.dart';

class GiftCatalogApiService {
  const GiftCatalogApiService();

  Future<GiftCatalogSnapshot> fetchActiveCatalog() async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/gifts/catalog')),
      headers: const <String, String>{'Accept': 'application/json'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gift catalog failed: HTTP ${response.statusCode}');
    }
    return GiftCatalogSnapshot.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

class GiftCatalogSnapshot {
  const GiftCatalogSnapshot({required this.catalogVersion, required this.categories, required this.gifts});

  final int catalogVersion;
  final List<GiftCatalogCategory> categories;
  final List<GiftItem> gifts;

  bool get isEmpty => categories.isEmpty || gifts.isEmpty;

  factory GiftCatalogSnapshot.fromJson(Map<String, dynamic> json) {
    final categories = (json['categories'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(GiftCatalogCategory.fromJson)
        .where((category) => category.isEnabled)
        .toList(growable: false);
    final gifts = (json['all'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(_giftFromJson)
        .toList(growable: false);
    final keysWithGifts = gifts.map((gift) => gift.categoryKey ?? gift.category.label.toLowerCase()).toSet();
    return GiftCatalogSnapshot(
      catalogVersion: _int(json['catalog_version']),
      categories: categories.where((category) => keysWithGifts.contains(category.key)).toList(growable: false),
      gifts: gifts,
    );
  }
}

class GiftCatalogCategory {
  const GiftCatalogCategory({required this.key, required this.label, required this.isEnabled, required this.sortOrder});
  final String key;
  final String label;
  final bool isEnabled;
  final int sortOrder;

  factory GiftCatalogCategory.fromJson(Map<String, dynamic> json) {
    final key = (json['key'] ?? '').toString().trim().toLowerCase();
    return GiftCatalogCategory(
      key: key,
      label: (json['label'] ?? key.replaceAll('_', ' ')).toString(),
      isEnabled: _bool(json['is_enabled'], fallback: true),
      sortOrder: _int(json['sort_order']),
    );
  }
}

GiftItem _giftFromJson(Map<String, dynamic> json) {
  final giftId = (json['id'] ?? '').toString();
  final giftName = (json['name'] ?? 'Gift').toString();
  final categoryKey = (json['category'] ?? 'classic').toString().trim().toLowerCase();
  final giftType = (json['gift_type'] ?? 'normal').toString().trim().toLowerCase();
  final minCombo = _int(json['min_combo']) <= 0 ? 1 : _int(json['min_combo']);
  final rawMaxCombo = _int(json['max_combo']);
  final maxCombo = rawMaxCombo == 0 ? 999 : (rawMaxCombo < minCombo ? minCombo : rawMaxCombo);
  final displayMode = (json['display_mode'] ?? 'normal').toString();
  final premium = categoryKey == 'premium' || _bool(json['show_premium_broadcast'], fallback: false);
  final lucky = giftType == 'lucky' || categoryKey == 'lucky';
  GiftPanelConstants.registerGiftComboLimit(giftId: giftId, minCombo: minCombo, maxCombo: maxCombo);
  GiftPanelConstants.registerGiftDisplayMode(giftId: giftId, giftName: giftName, displayMode: displayMode);
  return GiftItem(
    id: giftId,
    name: giftName,
    category: _categoryFromKey(categoryKey),
    categoryKey: categoryKey,
    coins: _int(json['coin_value']),
    icon: _iconFor(json['icon_key']?.toString(), categoryKey),
    chatSymbol: (json['chat_symbol'] ?? '*').toString(),
    assetPath: _text(json['asset_path']),
    videoAssetPath: _text(json['video_asset_path']),
    assetUrl: _text(json['asset_url']),
    videoUrl: _text(json['video_url']),
    colors: _colorsFor(categoryKey, isPremium: premium, isLucky: lucky),
    giftType: giftType,
    animationType: (json['animation_type'] ?? 'image').toString(),
    version: _int(json['version']) == 0 ? 1 : _int(json['version']),
    catalogVersion: _int(json['catalog_version']) == 0 ? 1 : _int(json['catalog_version']),
    showGiftSlide: _bool(json['show_gift_slide'], fallback: true),
    showPremiumBroadcast: _bool(json['show_premium_broadcast'], fallback: false),
    showGiftFlight: _bool(json['show_gift_flight'], fallback: true),
  );
}

GiftCategory _categoryFromKey(String key) {
  switch (key) {
    case 'classic': return GiftCategory.classic;
    case 'lucky': return GiftCategory.lucky;
    case 'relationship': return GiftCategory.relationship;
    case 'event': return GiftCategory.event;
    case 'premium': return GiftCategory.premium;
    case 'svip': return GiftCategory.svip;
    case 'vip': return GiftCategory.vip;
    case 'baggage': return GiftCategory.baggage;
    default: return GiftCategory.classic;
  }
}

IconData _iconFor(String? iconKey, String categoryKey) {
  switch (iconKey) {
    case 'local_rocket': return Icons.rocket_launch_rounded;
    case 'local_paid': return Icons.toll_rounded;
    case 'local_celebration': return Icons.celebration_rounded;
    case 'local_favorite':
    case 'local_favorite_border': return Icons.favorite_rounded;
    case 'local_auto_fix_high': return Icons.auto_fix_high_rounded;
    case 'local_auto_awesome': return Icons.auto_awesome_rounded;
    case 'local_workspace_premium': return Icons.workspace_premium_rounded;
    case 'local_flutter_dash': return Icons.flutter_dash_rounded;
    case 'local_sailing': return Icons.sailing_rounded;
    case 'local_castle': return Icons.castle_rounded;
    case 'local_diamond': return Icons.diamond_rounded;
    case 'local_pets': return Icons.pets_rounded;
    case 'local_wb_sunny': return Icons.wb_sunny_rounded;
    case 'local_waves': return Icons.waves_rounded;
    case 'local_auto_stories': return Icons.auto_stories_rounded;
  }
  if (categoryKey == 'premium') return Icons.workspace_premium_rounded;
  if (categoryKey == 'lucky') return Icons.casino_rounded;
  return Icons.card_giftcard_rounded;
}

List<Color> _colorsFor(String categoryKey, {required bool isPremium, required bool isLucky}) {
  if (isPremium) return const <Color>[Color(0xFFFFD166), Color(0xFF8C5CF6)];
  if (isLucky) return const <Color>[Color(0xFFFFC857), Color(0xFFE84C72)];
  return const <Color>[Color(0xFFFFC857), Color(0xFF12C7B7)];
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _bool(dynamic value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase().trim();
  if (text == 'true' || text == '1' || text == 'yes') return true;
  if (text == 'false' || text == '0' || text == 'no') return false;
  return fallback;
}
