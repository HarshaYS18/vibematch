import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_local_storage.dart';
import '../presentation/live_room_models.dart';

class MiniProfileEconomySummary {
  const MiniProfileEconomySummary({
    required this.monthlyGiftCoinsSent,
    required this.monthlyGiftCoinsReceived,
    required this.lifetimeSendExp,
    required this.lifetimeReceiveExp,
    required this.sentLevel,
    required this.receiveLevel,
  });

  final int monthlyGiftCoinsSent;
  final int monthlyGiftCoinsReceived;
  final int lifetimeSendExp;
  final int lifetimeReceiveExp;
  final int sentLevel;
  final int receiveLevel;

  factory MiniProfileEconomySummary.fromJson(Map<String, dynamic> json) {
    final sent = _map(json['sent']);
    final received = _map(json['received']);
    return MiniProfileEconomySummary(
      monthlyGiftCoinsSent: _int(json['monthly_gift_coins_sent']),
      monthlyGiftCoinsReceived: _int(json['monthly_gift_coins_received']),
      lifetimeSendExp: _int(json['lifetime_send_exp']) == 0
          ? _int(sent['total_exp'])
          : _int(json['lifetime_send_exp']),
      lifetimeReceiveExp: _int(json['lifetime_receive_exp']) == 0
          ? _int(received['total_exp'])
          : _int(json['lifetime_receive_exp']),
      sentLevel: _int(json['sent_level']) == 0
          ? _int(sent['level'])
          : _int(json['sent_level']),
      receiveLevel: _int(json['receive_level']) == 0
          ? _int(received['level'])
          : _int(json['receive_level']),
    );
  }

  factory MiniProfileEconomySummary.fromSeatUser(SeatUser user) {
    return MiniProfileEconomySummary(
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

  static final MiniProfileEconomyService instance = MiniProfileEconomyService._();
  final AuthLocalStorage _storage = AuthLocalStorage();
  final Map<int, Future<MiniProfileEconomySummary>> _cache = <int, Future<MiniProfileEconomySummary>>{};

  Future<MiniProfileEconomySummary> summaryForSeatUser(SeatUser user) {
    final publicUserId = _publicUserIdFromSeatId(user.id);
    if (publicUserId == null) {
      return Future<MiniProfileEconomySummary>.value(
        MiniProfileEconomySummary.fromSeatUser(user),
      );
    }
    return _cache.putIfAbsent(publicUserId, () => _fetch(publicUserId, user));
  }

  void clearCache() {
    _cache.clear();
  }

  Future<MiniProfileEconomySummary> _fetch(int publicUserId, SeatUser fallbackUser) async {
    try {
      final token = await _storage.getAccessToken();
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null && token.trim().isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await http.get(
        Uri.parse(VmApiConfig.endpoint('/economy/users/public/$publicUserId/summary')),
        headers: headers,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return MiniProfileEconomySummary.fromSeatUser(fallbackUser);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return MiniProfileEconomySummary.fromSeatUser(fallbackUser);
      }
      return MiniProfileEconomySummary.fromJson(decoded);
    } catch (_) {
      return MiniProfileEconomySummary.fromSeatUser(fallbackUser);
    }
  }

  int? _publicUserIdFromSeatId(String seatUserId) {
    final direct = int.tryParse(seatUserId.trim());
    if (direct != null && direct > 0) return direct;
    final match = RegExp(r'(\d{7,12})').firstMatch(seatUserId);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
