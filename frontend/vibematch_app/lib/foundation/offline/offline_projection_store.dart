import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small, rebuildable offline read projection.
///
/// This store is intentionally bounded and never queues authoritative commands.
/// SharedPreferences is used as a portable bootstrap cache, not as business
/// storage. Large media/content stays in normal HTTP/CDN caches.
class OfflineProjectionStore {
  OfflineProjectionStore._(this._preferences);

  final SharedPreferences _preferences;

  static const String _prefix = 'funkey.offline.v1.';
  static const String _indexKey = 'funkey.offline.v1.__index__';

  static const Set<String> allowedScopes = <String>{
    'home',
    'public_profile',
    'room_preview',
    'vibe_feed',
    'search_recent',
  };

  static const int maxPayloadBytes = 64 * 1024;
  static const int maxRows = 64;

  static Future<OfflineProjectionStore> open() async {
    return OfflineProjectionStore._(await SharedPreferences.getInstance());
  }

  Future<void> put({
    required String scope,
    required String key,
    required Map<String, dynamic> payload,
    required Duration ttl,
  }) async {
    _validateScope(scope);
    if (ttl <= Duration.zero || ttl > const Duration(days: 7)) {
      throw ArgumentError.value(ttl, 'ttl', 'must be >0 and <=7 days');
    }
    final encodedPayload = jsonEncode(payload);
    if (utf8.encode(encodedPayload).length > maxPayloadBytes) {
      throw ArgumentError(
        'offline projection payload exceeds $maxPayloadBytes bytes',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final storageKey = _storageKey(scope, key);
    final envelope = jsonEncode(<String, dynamic>{
      'payload': payload,
      'updatedAtMs': now,
      'expiresAtMs': now + ttl.inMilliseconds,
    });

    await _preferences.setString(storageKey, envelope);
    final index = await _readIndex();
    index.removeWhere((entry) => entry.key == storageKey);
    index.insert(0, _IndexEntry(storageKey, now));
    while (index.length > maxRows) {
      final removed = index.removeLast();
      await _preferences.remove(removed.key);
    }
    await _writeIndex(index);
    await clearExpired();
  }

  Future<Map<String, dynamic>?> get({
    required String scope,
    required String key,
  }) async {
    _validateScope(scope);
    final storageKey = _storageKey(scope, key);
    final raw = _preferences.getString(storageKey);
    if (raw == null) return null;

    try {
      final envelope = jsonDecode(raw);
      if (envelope is! Map<String, dynamic>) {
        await _preferences.remove(storageKey);
        return null;
      }
      final expiresAtMs = envelope['expiresAtMs'];
      if (expiresAtMs is! int ||
          expiresAtMs <= DateTime.now().millisecondsSinceEpoch) {
        await _preferences.remove(storageKey);
        return null;
      }
      final payload = envelope['payload'];
      return payload is Map<String, dynamic> ? payload : null;
    } catch (_) {
      await _preferences.remove(storageKey);
      return null;
    }
  }

  Future<void> clearExpired() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final index = await _readIndex();
    final kept = <_IndexEntry>[];
    for (final entry in index) {
      final raw = _preferences.getString(entry.key);
      if (raw == null) continue;
      try {
        final envelope = jsonDecode(raw);
        final expiresAtMs =
            envelope is Map<String, dynamic> ? envelope['expiresAtMs'] : null;
        if (expiresAtMs is int && expiresAtMs > now) {
          kept.add(entry);
        } else {
          await _preferences.remove(entry.key);
        }
      } catch (_) {
        await _preferences.remove(entry.key);
      }
    }
    await _writeIndex(kept);
  }

  Future<void> clearAll() async {
    final index = await _readIndex();
    for (final entry in index) {
      await _preferences.remove(entry.key);
    }
    await _preferences.remove(_indexKey);
  }

  Future<List<_IndexEntry>> _readIndex() async {
    final raw = _preferences.getString(_indexKey);
    if (raw == null) return <_IndexEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <_IndexEntry>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_IndexEntry.fromJson)
          .where((entry) => entry.key.startsWith(_prefix))
          .toList(growable: true);
    } catch (_) {
      return <_IndexEntry>[];
    }
  }

  Future<void> _writeIndex(List<_IndexEntry> index) {
    return _preferences.setString(
      _indexKey,
      jsonEncode(index.map((entry) => entry.toJson()).toList()),
    );
  }

  static String _storageKey(String scope, String key) {
    final safeKey = base64Url.encode(utf8.encode(key)).replaceAll('=', '');
    return '$_prefix$scope.$safeKey';
  }

  static void _validateScope(String scope) {
    if (!allowedScopes.contains(scope)) {
      throw ArgumentError.value(
        scope,
        'scope',
        'not approved for offline projection',
      );
    }
  }
}

class _IndexEntry {
  const _IndexEntry(this.key, this.updatedAtMs);

  final String key;
  final int updatedAtMs;

  factory _IndexEntry.fromJson(Map<String, dynamic> json) {
    return _IndexEntry(
      json['key']?.toString() ?? '',
      json['updatedAtMs'] is int ? json['updatedAtMs'] as int : 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'updatedAtMs': updatedAtMs,
      };
}

/// High-risk mutations are never queued while offline.
abstract final class OfflineMutationPolicy {
  static const Set<String> forbiddenPrefixes = <String>{
    'wallet.',
    'gift.',
    'purchase.',
    'payment.',
    'economy.',
    'room.membership.',
    'room.seat.',
    'moderation.',
    'auth.',
    'game.settlement.',
  };

  static bool mayQueue(String commandType) {
    final normalized = commandType.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return !forbiddenPrefixes.any(normalized.startsWith);
  }
}
