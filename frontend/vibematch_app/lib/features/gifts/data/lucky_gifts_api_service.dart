import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_local_storage.dart';

class LuckyGiftsApiService {
  const LuckyGiftsApiService();

  Future<LuckyGiftMaster> getMaster() async {
    final json = await _getMap('/lucky-gifts/master');
    return LuckyGiftMaster.fromJson(json);
  }

  Future<List<LuckyGiftCatalogItem>> getCatalog() async {
    final json = await _getMap('/lucky-gifts/catalog');
    final gifts = json['gifts'];
    if (gifts is! List) return const <LuckyGiftCatalogItem>[];
    return gifts
        .whereType<Map>()
        .map((item) => LuckyGiftCatalogItem.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<LuckyGiftPreview> preview({
    required String giftId,
    int quantity = 1,
    int? receiverPublicUserId,
    String? roomPublicId,
  }) async {
    final body = <String, dynamic>{
      'gift_id': giftId,
      'quantity': quantity,
    };
    if (receiverPublicUserId != null) {
      body['receiver_public_user_id'] = receiverPublicUserId;
    }
    final cleanRoomPublicId = roomPublicId?.trim();
    if (cleanRoomPublicId != null && cleanRoomPublicId.isNotEmpty) {
      body['room_public_id'] = cleanRoomPublicId;
    }

    final json = await _postMap('/lucky-gifts/preview', body: body);
    return LuckyGiftPreview.fromJson(json);
  }

  Future<LuckyGiftRecordResult> recordResult({
    required String giftId,
    int quantity = 1,
    int? receiverPublicUserId,
    String? roomPublicId,
    int spentCoins = 0,
    int multiplier = 0,
    int rewardCoins = 0,
    int netWinCoins = 0,
  }) async {
    final body = <String, dynamic>{
      'gift_id': giftId,
      'quantity': quantity,
      'spent_coins': spentCoins,
      'multiplier': multiplier,
      'reward_coins': rewardCoins,
      'net_win_coins': netWinCoins,
    };
    if (receiverPublicUserId != null) {
      body['receiver_public_user_id'] = receiverPublicUserId;
    }
    final cleanRoomPublicId = roomPublicId?.trim();
    if (cleanRoomPublicId != null && cleanRoomPublicId.isNotEmpty) {
      body['room_public_id'] = cleanRoomPublicId;
    }

    final json = await _postMap('/lucky-gifts/results/record', body: body);
    return LuckyGiftRecordResult.fromJson(json);
  }

  Future<List<LuckyGiftHistoryEntry>> getHistory({
    LuckyGiftPeriod period = LuckyGiftPeriod.daily,
    String? roomPublicId,
    String? giftId,
    int minMultiplier = 0,
    int limit = 50,
  }) async {
    final query = <String>[
      'period=${period.backendValue}',
      'min_multiplier=$minMultiplier',
      'limit=${limit.clamp(1, 100)}',
      if (roomPublicId != null && roomPublicId.trim().isNotEmpty) 'room_public_id=${Uri.encodeQueryComponent(roomPublicId.trim())}',
      if (giftId != null && giftId.trim().isNotEmpty) 'gift_id=${Uri.encodeQueryComponent(giftId.trim())}',
    ].join('&');
    final json = await _getMap('/lucky-gifts/history?$query');
    final entries = json['entries'];
    if (entries is! List) return const <LuckyGiftHistoryEntry>[];
    return entries
        .whereType<Map>()
        .map((item) => LuckyGiftHistoryEntry.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<LuckyGiftStats> getMyStats() async {
    final json = await _getMap('/lucky-gifts/me/stats');
    return LuckyGiftStats.fromJson(json);
  }

  Future<LuckyGiftPublicWinnings> getPublicWinnings({
    required int publicUserId,
    LuckyGiftPeriod period = LuckyGiftPeriod.monthly,
  }) async {
    final json = await _getMap(
      '/lucky-gifts/users/$publicUserId/winnings?period=${period.backendValue}',
    );
    return LuckyGiftPublicWinnings.fromJson(json);
  }

  Future<LuckyGiftRankingResponse> getRanking({
    LuckyGiftRankingType type = LuckyGiftRankingType.winnings,
    LuckyGiftPeriod period = LuckyGiftPeriod.daily,
    int limit = 100,
  }) async {
    final json = await _getMap(
      '/lucky-gifts/rankings/${type.backendValue}?period=${period.backendValue}&limit=${limit.clamp(1, 100)}',
    );
    return LuckyGiftRankingResponse.fromJson(
      json,
      fallbackType: type,
      fallbackPeriod: period,
    );
  }

  Future<LuckyGiftRollPreview> rollPreview({required int totalCoinValue}) async {
    final json = await _getMap(
      '/lucky-gifts/roll-preview?total_coin_value=$totalCoinValue',
    );
    return LuckyGiftRollPreview.fromJson(json);
  }

  Future<Map<String, dynamic>> _getMap(String path) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint(path)),
      headers: await _headers(),
    );
    return _decodeMap(response, 'GET $path');
  }

  Future<Map<String, dynamic>> _postMap(String path, {required Map<String, dynamic> body}) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint(path)),
      headers: {
        ...await _headers(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    return _decodeMap(response, 'POST $path');
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthLocalStorage().getAccessToken();
    return <String, String>{
      'Accept': 'application/json',
      if (token != null && token.trim().isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decodeMap(http.Response response, String label) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$label failed (${response.statusCode}): ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    return const <String, dynamic>{};
  }
}

enum LuckyGiftPeriod {
  daily,
  weekly,
  monthly,
  yearly;

  String get label {
    switch (this) {
      case LuckyGiftPeriod.daily:
        return 'Today';
      case LuckyGiftPeriod.weekly:
        return 'This week';
      case LuckyGiftPeriod.monthly:
        return 'This month';
      case LuckyGiftPeriod.yearly:
        return 'This year';
    }
  }

  String get backendValue {
    switch (this) {
      case LuckyGiftPeriod.daily:
        return 'daily';
      case LuckyGiftPeriod.weekly:
        return 'weekly';
      case LuckyGiftPeriod.monthly:
        return 'monthly';
      case LuckyGiftPeriod.yearly:
        return 'yearly';
    }
  }
}

enum LuckyGiftRankingType {
  winnings,
  netWins,
  bigWins,
  multipliers,
  spending;

  String get label {
    switch (this) {
      case LuckyGiftRankingType.winnings:
        return 'Winnings';
      case LuckyGiftRankingType.netWins:
        return 'Net wins';
      case LuckyGiftRankingType.bigWins:
        return 'Big wins';
      case LuckyGiftRankingType.multipliers:
        return 'Multipliers';
      case LuckyGiftRankingType.spending:
        return 'Spending';
    }
  }

  String get backendValue {
    switch (this) {
      case LuckyGiftRankingType.winnings:
        return 'winnings';
      case LuckyGiftRankingType.netWins:
        return 'net-wins';
      case LuckyGiftRankingType.bigWins:
        return 'big-wins';
      case LuckyGiftRankingType.multipliers:
        return 'multipliers';
      case LuckyGiftRankingType.spending:
        return 'spending';
    }
  }
}

class LuckyGiftMaster {
  const LuckyGiftMaster({
    required this.enabled,
    required this.currency,
    required this.multipliers,
    required this.rules,
  });

  final bool enabled;
  final String currency;
  final List<LuckyGiftMultiplierRule> multipliers;
  final Map<String, dynamic> rules;

  factory LuckyGiftMaster.fromJson(Map<String, dynamic> json) {
    final items = json['multipliers'];
    return LuckyGiftMaster(
      enabled: _bool(json['enabled'], fallback: true),
      currency: _string(json['currency'], fallback: 'coins'),
      multipliers: items is List
          ? items
                .whereType<Map>()
                .map((item) => LuckyGiftMultiplierRule.fromJson(item.cast<String, dynamic>()))
                .toList(growable: false)
          : const <LuckyGiftMultiplierRule>[],
      rules: _map(json['rules']),
    );
  }
}

class LuckyGiftMultiplierRule {
  const LuckyGiftMultiplierRule({
    required this.multiplier,
    required this.weight,
    required this.publicDisplay,
  });

  final int multiplier;
  final int weight;
  final bool publicDisplay;

  factory LuckyGiftMultiplierRule.fromJson(Map<String, dynamic> json) {
    return LuckyGiftMultiplierRule(
      multiplier: _int(json['multiplier']),
      weight: _int(json['weight']),
      publicDisplay: _bool(json['public_display'], fallback: false),
    );
  }
}

class LuckyGiftCatalogItem {
  const LuckyGiftCatalogItem({
    required this.id,
    required this.name,
    required this.coinValue,
    required this.assetPath,
    required this.raw,
  });

  final String id;
  final String name;
  final int coinValue;
  final String? assetPath;
  final Map<String, dynamic> raw;

  factory LuckyGiftCatalogItem.fromJson(Map<String, dynamic> json) {
    return LuckyGiftCatalogItem(
      id: _string(json['id'] ?? json['gift_id'] ?? json['gift_key'], fallback: ''),
      name: _string(json['name'] ?? json['gift_name'], fallback: 'Lucky Gift'),
      coinValue: _int(json['coin_value'] ?? json['price'] ?? json['coins']),
      assetPath: _nullableString(json['asset_path'] ?? json['asset'] ?? json['image_url']),
      raw: json,
    );
  }
}

class LuckyGiftPreview {
  const LuckyGiftPreview({
    required this.giftId,
    required this.quantity,
    required this.coinValue,
    required this.totalSpendCoins,
    required this.maxPossibleReward,
    required this.canSend,
  });

  final String giftId;
  final int quantity;
  final int coinValue;
  final int totalSpendCoins;
  final int maxPossibleReward;
  final bool canSend;

  factory LuckyGiftPreview.fromJson(Map<String, dynamic> json) {
    return LuckyGiftPreview(
      giftId: _string(json['gift_id'], fallback: ''),
      quantity: _int(json['quantity']),
      coinValue: _int(json['coin_value']),
      totalSpendCoins: _int(json['total_spend_coins']),
      maxPossibleReward: _int(json['max_possible_reward']),
      canSend: _bool(json['can_send'], fallback: true),
    );
  }
}

class LuckyGiftRecordResult {
  const LuckyGiftRecordResult({
    required this.status,
    required this.transactionId,
    required this.stats,
  });

  final String status;
  final int transactionId;
  final LuckyGiftStats stats;

  factory LuckyGiftRecordResult.fromJson(Map<String, dynamic> json) {
    return LuckyGiftRecordResult(
      status: _string(json['status'], fallback: ''),
      transactionId: _int(json['transaction_id']),
      stats: LuckyGiftStats.fromJson(_map(json['stats'])),
    );
  }
}

class LuckyGiftHistoryEntry {
  const LuckyGiftHistoryEntry({
    required this.transactionId,
    required this.senderUserId,
    required this.receiverUserId,
    required this.roomId,
    required this.giftId,
    required this.giftName,
    required this.spentCoins,
    required this.multiplier,
    required this.rewardCoins,
    required this.netWinCoins,
    required this.createdAt,
  });

  final int transactionId;
  final int senderUserId;
  final int receiverUserId;
  final int roomId;
  final String giftId;
  final String giftName;
  final int spentCoins;
  final int multiplier;
  final int rewardCoins;
  final int netWinCoins;
  final DateTime? createdAt;

  factory LuckyGiftHistoryEntry.fromJson(Map<String, dynamic> json) {
    return LuckyGiftHistoryEntry(
      transactionId: _int(json['transaction_id']),
      senderUserId: _int(json['sender_user_id']),
      receiverUserId: _int(json['receiver_user_id']),
      roomId: _int(json['room_id']),
      giftId: _string(json['gift_id'], fallback: ''),
      giftName: _string(json['gift_name'], fallback: 'Lucky Gift'),
      spentCoins: _int(json['spent_coins']),
      multiplier: _int(json['multiplier']),
      rewardCoins: _int(json['reward_coins']),
      netWinCoins: _int(json['net_win_coins']),
      createdAt: _date(json['created_at']),
    );
  }
}

class LuckyGiftStats {
  const LuckyGiftStats({
    required this.today,
    required this.weekly,
    required this.monthly,
    required this.yearly,
    required this.allTime,
  });

  final LuckyGiftStatsPeriod today;
  final LuckyGiftStatsPeriod weekly;
  final LuckyGiftStatsPeriod monthly;
  final LuckyGiftStatsPeriod yearly;
  final LuckyGiftStatsPeriod allTime;

  factory LuckyGiftStats.fromJson(Map<String, dynamic> json) {
    return LuckyGiftStats(
      today: LuckyGiftStatsPeriod.fromJson(_map(json['today'])),
      weekly: LuckyGiftStatsPeriod.fromJson(_map(json['weekly'])),
      monthly: LuckyGiftStatsPeriod.fromJson(_map(json['monthly'])),
      yearly: LuckyGiftStatsPeriod.fromJson(_map(json['yearly'])),
      allTime: LuckyGiftStatsPeriod.fromJson(_map(json['all_time'])),
    );
  }
}

class LuckyGiftStatsPeriod {
  const LuckyGiftStatsPeriod({
    required this.spentCoins,
    required this.rewardCoins,
    required this.netCoins,
    required this.bestMultiplier,
    required this.biggestReward,
    required this.rounds,
  });

  final int spentCoins;
  final int rewardCoins;
  final int netCoins;
  final int bestMultiplier;
  final int biggestReward;
  final int rounds;

  factory LuckyGiftStatsPeriod.fromJson(Map<String, dynamic> json) {
    return LuckyGiftStatsPeriod(
      spentCoins: _int(json['spent_coins']),
      rewardCoins: _int(json['reward_coins']),
      netCoins: _int(json['net_coins']),
      bestMultiplier: _int(json['best_multiplier']),
      biggestReward: _int(json['biggest_reward']),
      rounds: _int(json['rounds']),
    );
  }
}

class LuckyGiftPublicWinnings {
  const LuckyGiftPublicWinnings({
    required this.publicUserId,
    required this.period,
    required this.spentCoins,
    required this.rewardCoins,
    required this.netWinCoins,
    required this.bestMultiplier,
    required this.biggestReward,
    required this.luckyGiftsSent,
    required this.rank,
  });

  final int publicUserId;
  final LuckyGiftPeriod period;
  final int spentCoins;
  final int rewardCoins;
  final int netWinCoins;
  final int bestMultiplier;
  final int biggestReward;
  final int luckyGiftsSent;
  final int? rank;

  factory LuckyGiftPublicWinnings.fromJson(Map<String, dynamic> json) {
    return LuckyGiftPublicWinnings(
      publicUserId: _int(json['public_user_id']),
      period: _period(json['period'], LuckyGiftPeriod.monthly),
      spentCoins: _int(json['spent_coins']),
      rewardCoins: _int(json['reward_coins']),
      netWinCoins: _int(json['net_win_coins']),
      bestMultiplier: _int(json['best_multiplier']),
      biggestReward: _int(json['biggest_reward']),
      luckyGiftsSent: _int(json['lucky_gifts_sent']),
      rank: json['rank'] == null ? null : _int(json['rank']),
    );
  }
}

class LuckyGiftRankingResponse {
  const LuckyGiftRankingResponse({
    required this.type,
    required this.period,
    required this.entries,
  });

  final LuckyGiftRankingType type;
  final LuckyGiftPeriod period;
  final List<LuckyGiftRankingEntry> entries;

  factory LuckyGiftRankingResponse.fromJson(
    Map<String, dynamic> json, {
    required LuckyGiftRankingType fallbackType,
    required LuckyGiftPeriod fallbackPeriod,
  }) {
    final entries = json['entries'];
    return LuckyGiftRankingResponse(
      type: _rankingType(json['ranking_type'], fallbackType),
      period: _period(json['period'], fallbackPeriod),
      entries: entries is List
          ? entries
                .whereType<Map>()
                .map((item) => LuckyGiftRankingEntry.fromJson(item.cast<String, dynamic>()))
                .toList(growable: false)
          : const <LuckyGiftRankingEntry>[],
    );
  }
}

class LuckyGiftRankingEntry {
  const LuckyGiftRankingEntry({
    required this.rank,
    required this.score,
    required this.publicUserId,
    required this.displayName,
    required this.avatarUrl,
  });

  final int rank;
  final int score;
  final int publicUserId;
  final String displayName;
  final String? avatarUrl;

  factory LuckyGiftRankingEntry.fromJson(Map<String, dynamic> json) {
    final user = _map(json['user']);
    return LuckyGiftRankingEntry(
      rank: _int(json['rank']),
      score: _int(json['score']),
      publicUserId: _int(user['public_user_id']),
      displayName: _string(user['display_name'], fallback: 'Vibe User'),
      avatarUrl: _nullableString(user['avatar_url']),
    );
  }
}

class LuckyGiftRollPreview {
  const LuckyGiftRollPreview({
    required this.multiplier,
    required this.rewardCoinAmount,
    required this.previewOnly,
  });

  final int multiplier;
  final int rewardCoinAmount;
  final bool previewOnly;

  factory LuckyGiftRollPreview.fromJson(Map<String, dynamic> json) {
    return LuckyGiftRollPreview(
      multiplier: _int(json['multiplier']),
      rewardCoinAmount: _int(json['reward_coin_amount']),
      previewOnly: _bool(json['preview_only'], fallback: true),
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _string(Object? value, {required String fallback}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

bool _bool(Object? value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final text = value.trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
  }
  return fallback;
}

DateTime? _date(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}

LuckyGiftPeriod _period(Object? value, LuckyGiftPeriod fallback) {
  final text = value?.toString().trim().toLowerCase();
  if (text == 'daily' || text == 'today') return LuckyGiftPeriod.daily;
  if (text == 'weekly' || text == 'week') return LuckyGiftPeriod.weekly;
  if (text == 'monthly' || text == 'month') return LuckyGiftPeriod.monthly;
  if (text == 'yearly' || text == 'year') return LuckyGiftPeriod.yearly;
  return fallback;
}

LuckyGiftRankingType _rankingType(Object? value, LuckyGiftRankingType fallback) {
  final text = value?.toString().trim().toLowerCase().replaceAll('_', '-');
  if (text == 'winnings') return LuckyGiftRankingType.winnings;
  if (text == 'net-wins' || text == 'net') return LuckyGiftRankingType.netWins;
  if (text == 'big-wins' || text == 'biggest-reward') return LuckyGiftRankingType.bigWins;
  if (text == 'multipliers' || text == 'best-multiplier') return LuckyGiftRankingType.multipliers;
  if (text == 'spending' || text == 'spent') return LuckyGiftRankingType.spending;
  return fallback;
}
