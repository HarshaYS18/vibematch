// Verifies the pure RoomSessionState -> ChatEntry compatibility projection.
// Durable chat authority remains RoomSessionRepository/backend snapshots; this
// test contains no global notifier or transport dependency.
import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/rooms/data/room_session_legacy_adapter.dart';
import 'package:vibematch_app/room_session/domain/room_session_state.dart';

void main() {
  test('canonical room chat projects text and image messages newest first', () {
    final state = RoomSessionState.fromSnapshot(
      <String, dynamic>{
        'room_id': 'VMCHAT01',
        'recent_messages': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'message_type': 'text',
            'text': 'hello',
            'sender_public_user_id': 7000000001,
            'sender_room_user_key': 'user_7000000001',
            'sender': <String, dynamic>{
              'display_name': 'Alice',
              'avatar_url': 'https://cdn.example/alice.webp',
            },
          },
          <String, dynamic>{
            'id': 2,
            'message_type': 'image',
            'text': null,
            'media_url': 'https://cdn.example/room/photo.webp',
            'metadata': <String, dynamic>{'content_type': 'image/webp'},
            'sender_public_user_id': 7000000002,
            'sender_room_user_key': 'user_7000000002',
            'sender': <String, dynamic>{'display_name': 'Bob'},
          },
        ],
      },
      connection: RoomSessionConnection.connected,
    );

    final entries = RoomSessionLegacyAdapter.toChatEntries(state);

    expect(entries, hasLength(2));
    expect(entries.first.senderName, 'Bob');
    expect(entries.first.isImageMessage, isTrue);
    expect(entries.first.imageUrl, 'https://cdn.example/room/photo.webp');
    expect(entries.first.imageContentType, 'image/webp');
    expect(entries.last.senderName, 'Alice');
    expect(entries.last.message, 'hello');
    expect(entries.last.isImageMessage, isFalse);
  });

  test('empty canonical chat projects to an empty presentation list', () {
    final state = RoomSessionState.fromSnapshot(
      const <String, dynamic>{
        'room_id': 'VMCHAT02',
        'recent_messages': <Map<String, dynamic>>[],
      },
      connection: RoomSessionConnection.connected,
    );

    expect(RoomSessionLegacyAdapter.toChatEntries(state), isEmpty);
  });

  test('initial room state cannot overwrite restored chat before join', () {
    final initial = RoomSessionState.initial('VMCHAT03');

    expect(
      RoomSessionLegacyAdapter.canProjectCanonicalChat(initial),
      isFalse,
    );
    expect(RoomSessionLegacyAdapter.toChatEntries(initial), isEmpty);
  });

  test('connected canonical snapshot is eligible to replace restored chat', () {
    final connected = RoomSessionState.fromSnapshot(
      const <String, dynamic>{
        'room_id': 'VMCHAT04',
        'recent_messages': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 11,
            'message_type': '',
            'text': 'canonical',
            'sender_public_user_id': 7000000011,
            'sender': <String, dynamic>{'display_name': 'Canonical User'},
          },
        ],
      },
      connection: RoomSessionConnection.connected,
    );

    expect(
      RoomSessionLegacyAdapter.canProjectCanonicalChat(connected),
      isTrue,
    );
    final entries = RoomSessionLegacyAdapter.toChatEntries(connected);
    expect(entries, hasLength(1));
    expect(entries.single.message, 'canonical');
    expect(entries.single.isImageMessage, isFalse);
  });

  test('projection preserves repeated identical canonical messages', () {
    final state = RoomSessionState.fromSnapshot(
      const <String, dynamic>{
        'room_id': 'VMCHAT05',
        'recent_messages': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 21,
            'message_type': 'text',
            'text': 'same',
            'sender_public_user_id': 7000000021,
          },
          <String, dynamic>{
            'id': 22,
            'message_type': 'text',
            'text': 'same',
            'sender_public_user_id': 7000000021,
          },
        ],
      },
      connection: RoomSessionConnection.connected,
    );

    final entries = RoomSessionLegacyAdapter.toChatEntries(state);
    expect(entries, hasLength(2));
    expect(entries.map((entry) => entry.message), everyElement('same'));
  });

}
