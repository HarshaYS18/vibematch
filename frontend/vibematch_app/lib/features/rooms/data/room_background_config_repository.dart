import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../presentation/widgets/room_theme.dart';

class RoomBackgroundConfigRepository {
  const RoomBackgroundConfigRepository({ApiClient? apiClient})
      : _apiClient = apiClient;

  final ApiClient? _apiClient;

  ApiClient get _client => _apiClient ?? ApiClient();

  Future<List<RoomBackgroundTheme>> fetchBackgrounds({
    required String mode,
  }) async {
    final response = await _client.getList(
      '/rooms/backgrounds',
      queryParameters: {'mode': mode},
    );

    return response
        .whereType<Map<String, dynamic>>()
        .map(_themeFromJson)
        .where((theme) => theme.isActive)
        .toList();
  }

  RoomBackgroundTheme _themeFromJson(Map<String, dynamic> json) {
    final id = _asString(json['id'], 'room_background');
    final name = _asString(json['name'], id);
    final accent = _parseHexColor(
      _asString(json['accent'], '#12C7B7'),
      fallback: RoomColors.aqua,
    );
    final fallbackColors = _parseColorList(json['fallback_colors']);

    return RoomBackgroundTheme(
      id: id,
      name: name,
      assetPath: _asNullableString(json['asset_path']),
      imageUrl: _asNullableString(json['image_url']),
      thumbnailUrl: _asNullableString(json['thumbnail_url']),
      accent: accent,
      sourceType: _sourceType(json['source_type']),
      unlockType: _unlockType(json['unlock_type']),
      ownershipType: _ownershipType(json['ownership_type']),
      isDefault: json['is_default'] == true,
      isActive: json['is_active'] != false,
      overlayOpacity: _asDouble(json['overlay_opacity'], 0.42),
      fallbackColors: fallbackColors.isEmpty
          ? const [RoomColors.deep, RoomColors.plum]
          : fallbackColors,
    );
  }

  String _asString(Object? value, String fallback) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  String? _asNullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  double _asDouble(Object? value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  List<Color> _parseColorList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => _parseOptionalHexColor(item?.toString()))
        .whereType<Color>()
        .toList();
  }

  Color _parseHexColor(String? value, {required Color fallback}) {
    return _parseOptionalHexColor(value) ?? fallback;
  }

  Color? _parseOptionalHexColor(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.replaceFirst('#', '');
    final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  RoomBackgroundSourceType _sourceType(Object? value) {
    final type = value?.toString().trim();
    if (type == 'cricket') return RoomBackgroundSourceType.event;
    return RoomBackgroundSourceType.chatRoom;
  }

  RoomBackgroundUnlockType _unlockType(Object? value) {
    final type = value?.toString().trim();
    if (type == 'free') return RoomBackgroundUnlockType.free;
    return RoomBackgroundUnlockType.free;
  }

  RoomBackgroundOwnershipType _ownershipType(Object? value) {
    final type = value?.toString().trim();
    if (type == 'free') return RoomBackgroundOwnershipType.free;
    return RoomBackgroundOwnershipType.free;
  }
}
