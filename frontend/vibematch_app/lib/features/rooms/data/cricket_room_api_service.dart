import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class CricketRoomApiService {
  const CricketRoomApiService({AuthApiService auth = const AuthApiService()}) : _auth = auth;

  final AuthApiService _auth;

  Future<List<Map<String, dynamic>>> listTournaments(String roomId) async {
    final response = await _get('/rooms/$roomId/cricket/tournaments');
    final decoded = jsonDecode(response.body);
    if (decoded is List) return decoded.whereType<Map<String, dynamic>>().toList();
    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> createTournament({
    required String roomId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _post('/rooms/$roomId/cricket/tournaments', payload);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> deleteTournament({
    required String roomId,
    required int tournamentId,
    String? reason,
  }) async {
    final path = '/rooms/$roomId/cricket/tournaments/$tournamentId';
    final safeReason = reason?.trim();
    final uri = Uri.parse(VmApiConfig.endpoint(path)).replace(
      queryParameters: safeReason == null || safeReason.isEmpty ? null : {'reason': safeReason},
    );
    final response = await http.delete(uri, headers: await _headers());
    _ensureOk(response);
  }

  Future<Map<String, dynamic>> createMatch({
    required String roomId,
    int? tournamentId,
    required String matchType,
    required Map<String, dynamic> teamA,
    required Map<String, dynamic> teamB,
  }) async {
    final response = await _post('/rooms/$roomId/cricket/matches', {
      'tournament_id': tournamentId,
      'match_type': matchType,
      'team_a': teamA,
      'team_b': teamB,
    });
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setToss({
    required String roomId,
    required int matchId,
    required String tossWinnerTeamId,
    required String decision,
  }) async {
    final response = await _patch('/rooms/$roomId/cricket/matches/$matchId/toss', {
      'toss_winner_team_id': tossWinnerTeamId,
      'decision': decision,
    });
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setLineup({
    required String roomId,
    required int matchId,
    required String battingTeamId,
    required String bowlingTeamId,
    required String strikerPlayerId,
    required String nonStrikerPlayerId,
    required String bowlerPlayerId,
  }) async {
    final response = await _patch('/rooms/$roomId/cricket/matches/$matchId/lineup', {
      'batting_team_id': battingTeamId,
      'bowling_team_id': bowlingTeamId,
      'striker_player_id': strikerPlayerId,
      'non_striker_player_id': nonStrikerPlayerId,
      'bowler_player_id': bowlerPlayerId,
    });
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addBall({
    required String roomId,
    required int matchId,
    required Map<String, dynamic> event,
  }) async {
    final response = await _post('/rooms/$roomId/cricket/matches/$matchId/balls', event);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patchScore({
    required String roomId,
    required int matchId,
    required Map<String, dynamic> score,
    Map<String, dynamic>? result,
    List<Map<String, dynamic>>? pointsTable,
  }) async {
    final response = await _patch('/rooms/$roomId/cricket/matches/$matchId/score', {
      'score': score,
      ?'result': result,
      ?'points_table': pointsTable,
    });
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completeMatch({
    required String roomId,
    required int matchId,
    required Map<String, dynamic> score,
    required Map<String, dynamic> result,
    List<Map<String, dynamic>>? pointsTable,
  }) async {
    final response = await _post('/rooms/$roomId/cricket/matches/$matchId/complete', {
      'score': score,
      'result': result,
      ?'points_table': pointsTable,
    });
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<http.Response> _get(String path) async {
    final response = await http.get(Uri.parse(VmApiConfig.endpoint(path)), headers: await _headers());
    _ensureOk(response);
    return response;
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint(path)),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    _ensureOk(response);
    return response;
  }

  Future<http.Response> _patch(String path, Map<String, dynamic> body) async {
    final response = await http.patch(
      Uri.parse(VmApiConfig.endpoint(path)),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    _ensureOk(response);
    return response;
  }

  Future<Map<String, String>> _headers() async {
    final cachedToken = _auth.cachedAccessToken;
    if (cachedToken == null || cachedToken.trim().isEmpty) {
      throw Exception('Please login again before using Cricket Mode.');
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $cachedToken',
    };
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception('Cricket API failed (${response.statusCode}): ${response.body}');
  }
}
