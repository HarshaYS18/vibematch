import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/rooms/data/live_room_presence_repository.dart';

void main() {
  group('LiveRoomPresenceSnapshot', () {
    final participants = <Map<String, dynamic>>[
      <String, dynamic>{
        'public_user_id': 6418000001,
        'display_name': 'Online User',
        'primary_role': 'user',
        'is_online': true,
        'is_owner': false,
        'is_member': false,
        'is_room_admin': false,
      },
      <String, dynamic>{
        'public_user_id': 6418000002,
        'display_name': 'Offline Saved Member',
        'primary_role': 'user',
        'is_online': false,
        'is_owner': false,
        'is_member': true,
        'is_room_admin': false,
      },
    ];

    test('join snapshots contain only users currently online', () {
      final snapshot = LiveRoomPresenceSnapshot.fromJoinJson(
        <String, dynamic>{
          'room': <String, dynamic>{
            'id': 'VMTEST',
            'online_count': 1,
          },
          'participants': participants,
          'joined_user': participants.first,
          'should_show_entered_message': false,
        },
      );

      expect(snapshot.participants, hasLength(1));
      expect(snapshot.participants.single.name, 'Online User');
      expect(snapshot.onlineCount, 1);
    });

    test('roster snapshots preserve offline saved members', () {
      final snapshot = LiveRoomPresenceSnapshot.fromJson(
        <String, dynamic>{
          'room_id': 'VMTEST',
          'online_count': 1,
          'participants': participants,
        },
      );

      expect(snapshot.participants, hasLength(2));
      expect(
        snapshot.participants.map((user) => user.name),
        contains('Offline Saved Member'),
      );
    });
  });
}
