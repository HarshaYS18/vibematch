/// Immutable Cricket Mode setup DTOs used by the room-scoped runtime.
///
/// Chunk 33 removed the former process-global ValueNotifier signal from this
/// file. Runtime ownership now lives in LiveRoomControllerBundle.
class CricketQuickMatchPlayerSetup {
  const CricketQuickMatchPlayerSetup({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, Object?> toJson() {
    return <String, Object?>{'id': id, 'name': name};
  }

  factory CricketQuickMatchPlayerSetup.fromJson(Map<String, dynamic> json) {
    return CricketQuickMatchPlayerSetup(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Player',
    );
  }
}

class CricketQuickMatchTeamSetup {
  const CricketQuickMatchTeamSetup({
    required this.id,
    required this.name,
    required this.players,
  });

  final String id;
  final String name;
  final List<CricketQuickMatchPlayerSetup> players;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'players': players.map((player) => player.toJson()).toList(),
    };
  }

  factory CricketQuickMatchTeamSetup.fromJson(Map<String, dynamic> json) {
    final rawPlayers = json['players'];
    return CricketQuickMatchTeamSetup(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Team',
      players: rawPlayers is List
          ? rawPlayers
                .whereType<Map<String, dynamic>>()
                .map(CricketQuickMatchPlayerSetup.fromJson)
                .toList()
          : const <CricketQuickMatchPlayerSetup>[],
    );
  }
}

class CricketQuickMatchSetup {
  const CricketQuickMatchSetup({
    required this.roomId,
    required this.roomName,
    required this.teamA,
    required this.teamB,
    required this.overs,
    required this.wickets,
    required this.battingTeamId,
    required this.bowlingTeamId,
    required this.strikerId,
    required this.nonStrikerId,
    required this.bowlerId,
  });

  final String roomId;
  final String roomName;
  final CricketQuickMatchTeamSetup teamA;
  final CricketQuickMatchTeamSetup teamB;
  final int overs;
  final int wickets;
  final String battingTeamId;
  final String bowlingTeamId;
  final String strikerId;
  final String nonStrikerId;
  final String bowlerId;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'room_id': roomId,
      'room_name': roomName,
      'team_a': teamA.toJson(),
      'team_b': teamB.toJson(),
      'overs': overs,
      'wickets': wickets,
      'batting_team_id': battingTeamId,
      'bowling_team_id': bowlingTeamId,
      'striker_id': strikerId,
      'non_striker_id': nonStrikerId,
      'bowler_id': bowlerId,
    };
  }

  factory CricketQuickMatchSetup.fromJson(Map<String, dynamic> json) {
    final teamAJson = json['team_a'];
    final teamBJson = json['team_b'];

    return CricketQuickMatchSetup(
      roomId: json['room_id']?.toString() ?? '',
      roomName: json['room_name']?.toString() ?? 'Live Room',
      teamA: teamAJson is Map<String, dynamic>
          ? CricketQuickMatchTeamSetup.fromJson(teamAJson)
          : const CricketQuickMatchTeamSetup(
              id: 'qa',
              name: 'Team A',
              players: [],
            ),
      teamB: teamBJson is Map<String, dynamic>
          ? CricketQuickMatchTeamSetup.fromJson(teamBJson)
          : const CricketQuickMatchTeamSetup(
              id: 'qb',
              name: 'Team B',
              players: [],
            ),
      overs: int.tryParse(json['overs']?.toString() ?? '') ?? 5,
      wickets: int.tryParse(json['wickets']?.toString() ?? '') ?? 4,
      battingTeamId: json['batting_team_id']?.toString() ?? '',
      bowlingTeamId: json['bowling_team_id']?.toString() ?? '',
      strikerId: json['striker_id']?.toString() ?? '',
      nonStrikerId: json['non_striker_id']?.toString() ?? '',
      bowlerId: json['bowler_id']?.toString() ?? '',
    );
  }
}
