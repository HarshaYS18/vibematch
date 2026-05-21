import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_local_storage.dart';
import '../presentation/live_room_models.dart';

class MiniProfileEconomySummary {
  const MiniProfileEconomySummary({
    required this.vipLevel,
    required this.svipLevel,
    required this.monthlyGiftCoinsSent,
    required this.monthlyGiftCoinsReceived,
    required this.lifetimeSendExp,
    required this.lifetimeReceiveExp,
    required this.sentLevel,
    required this.receiveLevel,
  });

  final int vipLevel;
  final int svipLevel;
  final int monthlyGiftCoinsSent;
  final int monthlyGiftCoinsReceived;
  final int lifetimeSendExp;
  final int lifetimeReceiveExp;
  final int sentLevel;
  final int receiveLevel;

  factory MiniProfileEconomySummary.fromJson(Map<String, dynamic> json) {
    final sent = _map(json['sent']);
    final received = _map(json['received']);
    final vip = _map(json['vip']);
    final svip = _map(json['svip']);
    return MiniProfileEconomySummary(
      vipLevel: _firstPositive([json['vip_level'], vip['level']]),
      svipLevel: _firstPositive([json['svip_level'], svip['level']]),
      monthlyGiftCoinsSent: _firstPositive([
        json['monthly_gift_coins_sent'],
        json['monthly_sent_coins'],
      ]),
      monthlyGiftCoinsReceived: _firstPositive([
        json['monthly_gift_coins_received'],
        json['monthly_received_coins'],
      ]),
      lifetimeSendExp: _firstPositive([
        json['lifetime_send_exp'],
        json['total_sent_coins'],
        sent['total_exp'],
      ]),
      lifetimeReceiveExp: _firstPositive([
        json['lifetime_receive_exp'],
        json['total_received_coins'],
        received['total_exp'],
      ]),
      sentLevel: _firstPositive([json['sent_level'], sent['level']]),
      receiveLevel: _firstPositive([
        json['receive_level'],
        json['received_level'],
        received['level'],
      ]),
    );
  }

  factory MiniProfileEconomySummary.fromSeatUser(SeatUser user) {
    return MiniProfileEconomySummary(
      vipLevel: user.vipLevel,
      svipLevel: user.svipLevel,
      monthlyGiftCoinsSent: user.sentExp,
      monthlyGiftCoinsReceived: user.receivedExp,
      lifetimeSendExp: user.sentExp,
      lifetimeReceiveExp: user.receivedExp,
      sentLevel: user.sendingLevel,
      receiveLevel: user.receivingLevel,
    );
  }
}

class MiniProfileEconomyService {
  MiniProfileEconomyService._();

  static final MiniProfileEconomyService instance =
      MiniProfileEconomyService._();
  final AuthLocalStorage _storage = AuthLocalStorage();

  Future<MiniProfileEconomySummary> summaryForSeatUser(SeatUser user) async {
    final token = await _storage.getAccessToken();
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final ids = _lookupCandidates(user.id);
    for (final candidate in ids) {
      final summary = await _tryFetch(candidate.path, headers);
      if (summary != null) return summary;
    }

    return MiniProfileEconomySummary.fromSeatUser(user);
  }

  void clearCache() {
    // Kept for callers, but mini profile must always fetch fresh backend values.
  }

  Future<MiniProfileEconomySummary?> _tryFetch(
    String path,
    Map<String, String> headers,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(VmApiConfig.endpoint(path)),
        headers: headers,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return MiniProfileEconomySummary.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  List<_MiniProfileLookupCandidate> _lookupCandidates(String seatUserId) {
    final value = seatUserId.trim();
    final candidates = <_MiniProfileLookupCandidate>[];
    final direct = int.tryParse(value);
    if (direct != null && direct > 0) {
      if (value.length >= 7) {
        candidates.add(
          _MiniProfileLookupCandidate('/profile-display/users/$direct'),
        );
        candidates.add(
          _MiniProfileLookupCandidate('/economy/users/public/$direct/summary'),
        );
      }
      candidates.add(
        _MiniProfileLookupCandidate('/economy/users/$direct/summary'),
      );
    }

    final match = RegExp(r'(\d{1,12})').firstMatch(value);
    final extracted = int.tryParse(match?.group(1) ?? '');
    if (extracted != null && extracted > 0 && extracted != direct) {
      if ('$extracted'.length >= 7) {
        candidates.add(
          _MiniProfileLookupCandidate('/profile-display/users/$extracted'),
        );
        candidates.add(
          _MiniProfileLookupCandidate(
            '/economy/users/public/$extracted/summary',
          ),
        );
      }
      candidates.add(
        _MiniProfileLookupCandidate('/economy/users/$extracted/summary'),
      );
    }

    return candidates;
  }
}

class _MiniProfileLookupCandidate {
  const _MiniProfileLookupCandidate(this.path);
  final String path;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

int _firstPositive(List<dynamic> values) {
  for (final value in values) {
    final parsed = _int(value);
    if (parsed > 0) return parsed;
  }
  return 0;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
