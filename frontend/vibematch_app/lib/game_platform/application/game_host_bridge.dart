import '../../foundation/networking/app_network_client.dart';

typedef GameHostClose = void Function();

class GameHostBridge {
  GameHostBridge({
    required AppNetworkClient api,
    required String accessToken,
    required String gameId,
    required int bridgeVersion,
    required GameHostClose onClose,
    String? roomId,
  }) : _api = api,
       _accessToken = accessToken,
       _gameId = gameId,
       _bridgeVersion = bridgeVersion,
       _roomId = roomId,
       _onClose = onClose;

  final AppNetworkClient _api;
  final String _accessToken;
  final String _gameId;
  final int _bridgeVersion;
  final String? _roomId;
  final GameHostClose _onClose;
  final Set<int> _authorizedRoundIds = <int>{};

  Future<Map<String, dynamic>> handle(dynamic rawRequest) async {
    try {
      final request = _requestMap(rawRequest);
      final method = request['method']?.toString().trim() ?? '';
      final params = _map(request['params']);

      final data = switch (method) {
        'host.context' => _context(),
        'host.close' => _close(),
        'game.round.create' => await _createRound(),
        'game.round.get' => await _getRound(params),
        'game.bet.place' => await _placeBet(params),
        'game.round.settle' => await _settleRound(params),
        'game.history' => await _history(params),
        _ => throw const GameBridgeException('Unsupported host bridge method.'),
      };

      return <String, dynamic>{'ok': true, 'data': data};
    } on GameBridgeException catch (error) {
      return <String, dynamic>{'ok': false, 'error': error.message};
    } catch (_) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'Game request failed.',
      };
    }
  }

  Map<String, dynamic> _context() => <String, dynamic>{
    'gameId': _gameId,
    'roomId': _roomId,
    'bridgeVersion': _bridgeVersion,
  };

  Map<String, dynamic> _close() {
    _onClose();
    return const <String, dynamic>{'closed': true};
  }

  Future<Map<String, dynamic>> _createRound() async {
    final response = await _api.postMap(
      '/games/${Uri.encodeComponent(_gameId)}/rounds',
      headers: _authHeaders,
      body: <String, dynamic>{'room_id': int.tryParse(_roomId ?? '')},
    );
    final roundId = _positiveInt(response['id'], 'round id');
    _authorizedRoundIds.add(roundId);
    return response;
  }

  Future<Map<String, dynamic>> _getRound(Map<String, dynamic> params) async {
    final roundId = _authorizedRoundId(params);
    return _api.getMap(
      '/games/rounds/$roundId',
      headers: _authHeaders,
    );
  }

  Future<Map<String, dynamic>> _placeBet(Map<String, dynamic> params) async {
    final roundId = _authorizedRoundId(params);
    final targetId = _int(params['targetId'], 'targetId');
    final amount = _positiveInt(params['amount'], 'amount');
    return _api.postMap(
      '/games/rounds/$roundId/bets',
      headers: _authHeaders,
      body: <String, dynamic>{
        'target_id': targetId,
        'amount': amount,
      },
    );
  }

  Future<Map<String, dynamic>> _settleRound(
    Map<String, dynamic> params,
  ) async {
    final roundId = _authorizedRoundId(params);
    return _api.postMap(
      '/games/rounds/$roundId/settle-test',
      headers: _authHeaders,
    );
  }

  Future<Map<String, dynamic>> _history(Map<String, dynamic> params) async {
    if (_gameId != 'jungle_hunt') {
      throw const GameBridgeException(
        'History is not available for this game.',
      );
    }
    final requested = _int(params['limit'] ?? 30, 'limit');
    final limit = requested.clamp(1, 30);
    return _api.getMap(
      '/games/global/jungle-hunt/history',
      queryParameters: <String, String?>{'limit': '$limit'},
      headers: _authHeaders,
    );
  }

  int _authorizedRoundId(Map<String, dynamic> params) {
    final roundId = _positiveInt(params['roundId'], 'roundId');
    if (!_authorizedRoundIds.contains(roundId)) {
      throw const GameBridgeException(
        'Round is not authorized for this game session.',
      );
    }
    return roundId;
  }

  Map<String, String> get _authHeaders => <String, String>{
    'Authorization': 'Bearer $_accessToken',
  };

  Map<String, dynamic> _requestMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const GameBridgeException('Invalid host bridge request.');
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value == null) return <String, dynamic>{};
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const GameBridgeException('Invalid host bridge parameters.');
  }

  int _int(dynamic value, String name) {
    final parsed = switch (value) {
      int number => number,
      num number => number.toInt(),
      String text => int.tryParse(text),
      _ => null,
    };
    if (parsed == null) {
      throw GameBridgeException('Invalid $name.');
    }
    return parsed;
  }

  int _positiveInt(dynamic value, String name) {
    final parsed = _int(value, name);
    if (parsed <= 0) throw GameBridgeException('Invalid $name.');
    return parsed;
  }
}

class GameBridgeException implements Exception {
  const GameBridgeException(this.message);

  final String message;
}
