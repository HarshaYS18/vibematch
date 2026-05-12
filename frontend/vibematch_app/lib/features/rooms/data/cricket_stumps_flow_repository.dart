import 'cricket_room_api_service.dart';

class CricketStumpsFlowRepository {
  const CricketStumpsFlowRepository({
    CricketRoomApiService api = const CricketRoomApiService(),
  }) : _api = api;

  final CricketRoomApiService _api;

  Future<List<Map<String, dynamic>>> loadTournaments(String roomId) {
    return _api.listTournaments(roomId);
  }

  Future<Map<String, dynamic>> saveTournament({
    required String roomId,
    required String name,
    required int teamCount,
    required int playersPerTeam,
    required int overs,
    required int wickets,
    required int matchesPerTeam,
    required int matchesVsEachTeam,
    required bool allowSamePlayerAcrossTeams,
    required List<Map<String, dynamic>> teams,
    required List<Map<String, dynamic>> fixtures,
  }) {
    return _api.createTournament(
      roomId: roomId,
      payload: {
        'name': name,
        'team_count': teamCount,
        'players_per_team': playersPerTeam,
        'overs_per_innings': overs,
        'wickets_per_side': wickets,
        'matches_per_team': matchesPerTeam,
        'matches_vs_each_team': matchesVsEachTeam,
        'allow_same_player_across_teams': allowSamePlayerAcrossTeams,
        'rules': {
          'type': 'league',
          'win_points': 2,
          'tie_points': 1,
          'super_over_enabled': true,
        },
        'teams': teams,
        'fixtures': fixtures,
      },
    );
  }

  Future<void> deleteTournament({
    required String roomId,
    required int tournamentId,
    String? reason,
  }) {
    return _api.deleteTournament(
      roomId: roomId,
      tournamentId: tournamentId,
      reason: reason,
    );
  }

  Future<Map<String, dynamic>> createMatch({
    required String roomId,
    required int? tournamentId,
    required bool isQuickMatch,
    required Map<String, dynamic> teamA,
    required Map<String, dynamic> teamB,
  }) {
    return _api.createMatch(
      roomId: roomId,
      tournamentId: tournamentId,
      matchType: isQuickMatch ? 'quick' : 'tournament',
      teamA: teamA,
      teamB: teamB,
    );
  }

  Future<Map<String, dynamic>> setToss({
    required String roomId,
    required int matchId,
    required String tossWinnerTeamId,
    required String decision,
  }) {
    return _api.setToss(
      roomId: roomId,
      matchId: matchId,
      tossWinnerTeamId: tossWinnerTeamId,
      decision: decision,
    );
  }

  Future<Map<String, dynamic>> setLineup({
    required String roomId,
    required int matchId,
    required String battingTeamId,
    required String bowlingTeamId,
    required String strikerPlayerId,
    required String nonStrikerPlayerId,
    required String bowlerPlayerId,
  }) {
    return _api.setLineup(
      roomId: roomId,
      matchId: matchId,
      battingTeamId: battingTeamId,
      bowlingTeamId: bowlingTeamId,
      strikerPlayerId: strikerPlayerId,
      nonStrikerPlayerId: nonStrikerPlayerId,
      bowlerPlayerId: bowlerPlayerId,
    );
  }
}
