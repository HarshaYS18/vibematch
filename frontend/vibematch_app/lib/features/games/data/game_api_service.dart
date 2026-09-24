import 'dart:convert';

import 'package:vibematch_app/foundation/networking/feature_http_compat.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class GameApiService {
  const GameApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<List<GameDefinition>> loadCatalog() async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/games/catalog')),
    );
    _throwIfFailed(response, 'load game catalog');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final games = decoded['games'] as List<dynamic>? ?? const [];
    return games
        .whereType<Map<String, dynamic>>()
        .map(GameDefinition.fromJson)
        .toList(growable: false);
  }

  Future<GameDefinition> seedDefaultGames() async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/admin/games/seed-defaults')),
      headers: await _headers(),
    );
    _throwIfFailed(response, 'seed default games');
    return GameDefinition.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<GameRound> createRound({required String gameKey, int? roomId}) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/games/$gameKey/rounds')),
      headers: await _headers(),
      body: jsonEncode({'room_id': roomId}),
    );
    _throwIfFailed(response, 'create game round');
    return GameRound.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<GameRound> getRound(int roundId) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/games/rounds/$roundId')),
      headers: await _headers(),
    );
    _throwIfFailed(response, 'load game round');
    return GameRound.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<GameBetResult> placeBet({
    required int roundId,
    required int targetId,
    required int amount,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/games/rounds/$roundId/bets')),
      headers: await _headers(),
      body: jsonEncode({'target_id': targetId, 'amount': amount}),
    );
    _throwIfFailed(response, 'place game bet');
    return GameBetResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<GameRoundResult> settleTestRound(int roundId) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/games/rounds/$roundId/settle-test')),
      headers: await _headers(),
    );
    _throwIfFailed(response, 'settle game round');
    return GameRoundResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Map<String, String>> _headers() async {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before playing games.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void _throwIfFailed(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception(_errorMessage(response, action));
  }

  String _errorMessage(http.Response response, String action) {
    var detail = response.body.trim();
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final rawDetail =
            decoded['detail'] ?? decoded['message'] ?? decoded['error'];
        if (rawDetail != null) detail = rawDetail.toString();
      }
    } catch (_) {
      // Keep the raw response body when the backend does not return JSON.
    }
    if (detail.isEmpty) detail = 'Request failed.';
    return 'Game API failed to $action (${response.statusCode}): $detail';
  }
}

class GameDefinition {
  const GameDefinition({
    required this.gameKey,
    required this.displayName,
    required this.category,
    required this.isEnabled,
    required this.isCoinGame,
    required this.minAppVersion,
    required this.configVersion,
    required this.cdnBaseUrl,
    required this.configUrl,
    required this.assetManifestUrl,
    required this.uiConfig,
    required this.rules,
    required this.risk,
  });

  final String gameKey;
  final String displayName;
  final String category;
  final bool isEnabled;
  final bool isCoinGame;
  final String minAppVersion;
  final int configVersion;
  final String? cdnBaseUrl;
  final String? configUrl;
  final String? assetManifestUrl;
  final Map<String, dynamic> uiConfig;
  final Map<String, dynamic> rules;
  final Map<String, dynamic> risk;

  factory GameDefinition.fromJson(Map<String, dynamic> json) => GameDefinition(
    gameKey: json['game_key']?.toString() ?? '',
    displayName: json['display_name']?.toString() ?? 'Game',
    category: json['category']?.toString() ?? 'coin',
    isEnabled: json['is_enabled'] == true,
    isCoinGame: json['is_coin_game'] != false,
    minAppVersion: json['min_app_version']?.toString() ?? '1.0.0',
    configVersion: _int(json['config_version']),
    cdnBaseUrl: _text(json['cdn_base_url']),
    configUrl: _text(json['config_url']),
    assetManifestUrl: _text(json['asset_manifest_url']),
    uiConfig: _map(json['ui_config']),
    rules: _map(json['rules']),
    risk: _map(json['risk']),
  );

  List<GameTarget> get targets {
    final rawTargets = rules['targets'];
    if (rawTargets is! List) return const <GameTarget>[];
    return rawTargets
        .whereType<Map<String, dynamic>>()
        .map(GameTarget.fromJson)
        .toList(growable: false);
  }

  List<int> get allowedBets {
    final rawBets = rules['allowed_bets'];
    if (rawBets is! List) return const [10000, 50000, 100000, 500000, 1000000];
    final parsed = rawBets
        .map(_int)
        .where((item) => item > 0)
        .toList(growable: false);
    return parsed.isEmpty
        ? const [10000, 50000, 100000, 500000, 1000000]
        : parsed;
  }
}

class GameTarget {
  const GameTarget({
    required this.id,
    required this.label,
    required this.emoji,
    required this.multiplier,
    required this.themeColor,
  });

  final int id;
  final String label;
  final String? emoji;
  final int multiplier;
  final String? themeColor;

  factory GameTarget.fromJson(Map<String, dynamic> json) => GameTarget(
    id: _int(json['id']),
    label: json['label']?.toString() ?? 'Target',
    emoji: _text(json['emoji']),
    multiplier: _int(json['multiplier']),
    themeColor: _text(json['theme_color']),
  );
}

class GameRound {
  const GameRound({
    required this.id,
    required this.gameKey,
    required this.roomId,
    required this.status,
    required this.entryFee,
    required this.roundPoolAmount,
    required this.metadata,
  });

  final int id;
  final String gameKey;
  final int? roomId;
  final String status;
  final int entryFee;
  final int roundPoolAmount;
  final Map<String, dynamic> metadata;

  factory GameRound.fromJson(Map<String, dynamic> json) => GameRound(
    id: _int(json['id']),
    gameKey: json['game_key']?.toString() ?? '',
    roomId: _nullableInt(json['room_id']),
    status: json['status']?.toString() ?? 'CREATED',
    entryFee: _int(json['entry_fee']),
    roundPoolAmount: _int(json['round_pool_amount']),
    metadata: _map(json['metadata']),
  );
}

class GameBetResult {
  const GameBetResult({
    required this.betId,
    required this.roundId,
    required this.targetId,
    required this.requestedAmount,
    required this.acceptedAmount,
    required this.walletCoinBalance,
    required this.riskLevel,
    required this.riskScore,
    required this.riskAction,
    required this.message,
  });

  final int? betId;
  final int roundId;
  final int targetId;
  final int requestedAmount;
  final int acceptedAmount;
  final int walletCoinBalance;
  final String riskLevel;
  final int riskScore;
  final String riskAction;
  final String message;

  factory GameBetResult.fromJson(Map<String, dynamic> json) => GameBetResult(
    betId: _nullableInt(json['bet_id']),
    roundId: _int(json['round_id']),
    targetId: _int(json['target_id']),
    requestedAmount: _int(json['requested_amount']),
    acceptedAmount: _int(json['accepted_amount']),
    walletCoinBalance: _int(json['wallet_coin_balance']),
    riskLevel: json['risk_level']?.toString() ?? 'LOW',
    riskScore: _int(json['risk_score']),
    riskAction: json['risk_action']?.toString() ?? 'ALLOW',
    message: json['message']?.toString() ?? '',
  );

  bool get shouldShowLoadingOverlay {
    final normalized = riskAction.trim().toUpperCase();
    return acceptedAmount <= 0 ||
        normalized == 'TAP_IGNORED_COOLDOWN' ||
        normalized == 'IGNORE' ||
        normalized == 'IGNORED';
  }

  bool get wasLimited => acceptedAmount > 0 && acceptedAmount < requestedAmount;
}

class GameRoundResult {
  const GameRoundResult({
    required this.roundId,
    required this.gameKey,
    required this.status,
    required this.winningTargetId,
    required this.multiplier,
    required this.totalUserBet,
    required this.totalUserWinnings,
    required this.walletCoinBalance,
    required this.riskAction,
    required this.auditMessage,
    required this.topWinners,
  });

  final int roundId;
  final String gameKey;
  final String status;
  final int winningTargetId;
  final int multiplier;
  final int totalUserBet;
  final int totalUserWinnings;
  final int walletCoinBalance;
  final String riskAction;
  final String auditMessage;
  final List<GameRoundWinner> topWinners;

  factory GameRoundResult.fromJson(Map<String, dynamic> json) {
    final winners = json['top_winners'] as List<dynamic>? ?? const [];
    return GameRoundResult(
      roundId: _int(json['round_id']),
      gameKey: json['game_key']?.toString() ?? '',
      status: json['status']?.toString() ?? 'COMPLETED',
      winningTargetId: _int(json['winning_target_id']),
      multiplier: _int(json['multiplier']),
      totalUserBet: _int(json['total_user_bet']),
      totalUserWinnings: _int(json['total_user_winnings']),
      walletCoinBalance: _int(json['wallet_coin_balance']),
      riskAction: json['risk_action']?.toString() ?? 'AUDIT',
      auditMessage: json['audit_message']?.toString() ?? '',
      topWinners: winners
          .whereType<Map<String, dynamic>>()
          .map(GameRoundWinner.fromJson)
          .toList(growable: false),
    );
  }
}

class GameRoundWinner {
  const GameRoundWinner({
    required this.userId,
    required this.name,
    required this.avatar,
    required this.coins,
  });

  final int userId;
  final String name;
  final String avatar;
  final int coins;

  factory GameRoundWinner.fromJson(Map<String, dynamic> json) =>
      GameRoundWinner(
        userId: _int(json['user_id']),
        name: json['name']?.toString() ?? 'Player',
        avatar: json['avatar']?.toString() ?? 'U',
        coins: _int(json['coins']),
      );
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
