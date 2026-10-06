import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/rooms/data/room_pk_api_service.dart';

Map<String, dynamic> matchJson({
  String status = 'active',
  String? winnerRoomId,
  int challengerScore = 120,
  int opponentScore = 80,
}) {
  return <String, dynamic>{
    'match_id': 'pk_test',
    'status': status,
    'challenger': <String, dynamic>{
      'room_id': 'ROOM_A',
      'room_name': 'Alpha Room',
      'online_count': 12,
    },
    'opponent': <String, dynamic>{
      'room_id': 'ROOM_B',
      'room_name': 'Beta Room',
      'online_count': 9,
    },
    'duration_seconds': 180,
    'challenger_score': challengerScore,
    'opponent_score': opponentScore,
    'winner_room_id': winnerRoomId,
    'challenge_expires_at': '2026-10-06T10:00:00Z',
    'started_at': '2026-10-06T09:57:00Z',
    'ends_at': '2026-10-06T10:00:00Z',
  };
}

void main() {
  test('PK snapshot resolves local and opponent scores by room identity', () {
    final match = RoomPkMatchSnapshot.fromJson(matchJson());

    expect(match.isActive, isTrue);
    expect(match.scoreFor('ROOM_A'), 120);
    expect(match.opponentScoreFor('ROOM_A'), 80);
    expect(match.scoreFor('ROOM_B'), 80);
    expect(match.opponentFor('ROOM_A').roomId, 'ROOM_B');
  });

  test('winner comes from backend snapshot rather than client score inference', () {
    final match = RoomPkMatchSnapshot.fromJson(
      matchJson(
        status: 'finished',
        winnerRoomId: 'ROOM_B',
        challengerScore: 999,
        opponentScore: 1,
      ),
    );

    expect(match.isFinished, isTrue);
    expect(match.winnerRoomId, 'ROOM_B');
  });
}
