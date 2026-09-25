// Source-level guard for canonical room ownership boundaries.
//
// This complements behavioral repository tests by ensuring text/image chat,
// settings and room UI coordination stay on canonical/scoped owners. It
 // deliberately forbids a return to media-singleton durable mutations.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chunk 5 canonical room state keeps domain concepts separate', () {
    final state = File(
      'lib/room_session/domain/room_session_state.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/room_session/data/room_session_repository.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/features/rooms/presentation/live_room_presence_shell_page.dart',
    ).readAsStringSync();

    expect(state, contains('final Map<int, RoomSessionParticipant> presence'));
    expect(state, contains('final Map<int, RoomSessionParticipant> audience'));
    expect(state, contains('final Map<int, RoomMembershipEntry> membershipRoster'));
    expect(state, contains('final Map<int, RoomSessionSeat> seats'));
    expect(repository, contains('/realtime/join'));
    expect(repository, isNot(contains('/realtime/heartbeat')));
    expect(shell, isNot(contains('Duration(seconds: 12)')));
    expect(repository, contains('/realtime/snapshot'));
    expect(shell, contains('roomSessionRepositoryProvider'));
    expect(repository, isNot(contains('ValueNotifier')));
    expect(repository, isNot(contains('package:http/http.dart')));
  });
  test('Chunk 33 image send awaits canonical repository before success UI', () {
    final controller = File(
      'lib/features/rooms/presentation/controllers/live_room_message_controller.dart',
    ).readAsStringSync();
    final dock = File(
      'lib/features/rooms/presentation/widgets/live_room_input_dock.dart',
    ).readAsStringSync();

    expect(controller, contains('Future<void> sendImageMessage'));
    expect(controller, contains('await repository.sendChatMessage('));
    expect(controller, contains("messageType: 'image'"));
    expect(
      controller,
      isNot(contains('LiveRoomMediaSignalingService.instance.sendRoomChat')),
    );

    final awaitIndex = dock.indexOf('await onImageMessage(');
    final successIndex = dock.indexOf("RoomToast.show(context, 'Image sent')");
    expect(awaitIndex, greaterThanOrEqualTo(0));
    expect(successIndex, greaterThan(awaitIndex));
  });


  test('Chunk 33 chat clear has one canonical room-scoped mutation path', () {
    final settings = File(
      'lib/features/rooms/presentation/modules/settings/live_room_settings_module.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/room_session/data/room_session_repository.dart',
    ).readAsStringSync();
    final media = File(
      'lib/features/rooms/data/live_room_media_signaling_service.dart',
    ).readAsStringSync();
    final messages = File(
      'lib/features/rooms/presentation/controllers/live_room_message_controller.dart',
    ).readAsStringSync();
    final feed = File(
      'lib/features/rooms/presentation/widgets/room_chat.dart',
    ).readAsStringSync();

    expect(repository, contains('Future<RoomSessionState> clearChat()'));
    expect(repository, contains('/realtime/chat/clear'));
    expect(settings, contains('await bundle.roomSessionRepository.clearChat();'));
    expect(media, isNot(contains('broadcastChatCleared')));
    expect(messages, isNot(contains('clearChatForEveryone')));
    expect(feed, isNot(contains('roomChatClearSignal')));
  });


  test('Chunk 33 room UI has no process-global notifier coordination', () {
    final theme = File(
      'lib/features/rooms/presentation/widgets/room_theme.dart',
    ).readAsStringSync();
    final seats = File(
      'lib/features/rooms/presentation/widgets/room_seats.dart',
    ).readAsStringSync();
    final dock = File(
      'lib/features/rooms/presentation/widgets/live_room_input_dock.dart',
    ).readAsStringSync();
    final layout = File(
      'lib/features/rooms/presentation/modules/layout/live_room_layout_module.dart',
    ).readAsStringSync();

    expect(theme, isNot(contains('activeRoomBackgroundTheme')));
    expect(seats, isNot(contains('roomSeatActionDismissSignal')));
    expect(seats, isNot(contains('dismissRoomSeatActionPill')));
    expect(dock, contains('final VoidCallback onDismissSeatActions'));
    expect(
      layout,
      contains('onDismissSeatActions: bundle.seatController.clearSelectedSeat'),
    );
  });


  test('Chunk 33 text chat also uses the canonical repository', () {
    final controller = File(
      'lib/features/rooms/presentation/controllers/live_room_message_controller.dart',
    ).readAsStringSync();
    final chatModule = File(
      'lib/features/rooms/presentation/modules/chat/live_room_chat_module.dart',
    ).readAsStringSync();
    final media = File(
      'lib/features/rooms/data/live_room_media_signaling_service.dart',
    ).readAsStringSync();

    expect(controller, contains('Future<void> sendMessage(String text)'));
    expect(controller, contains('await repository.sendChatMessage(text: trimmed);'));
    expect(chatModule, contains('await bundle.roomMessageController.sendMessage(text);'));
    expect(media, isNot(contains('void sendRoomChat(')));
  });

  test('Chunk 33 media facade cannot originate durable room settings', () {
    final stateController = File(
      'lib/features/rooms/presentation/controllers/live_room_state_controller.dart',
    ).readAsStringSync();
    final settingsRepository = File(
      'lib/features/rooms/data/room_settings_repository.dart',
    ).readAsStringSync();
    final media = File(
      'lib/features/rooms/data/live_room_media_signaling_service.dart',
    ).readAsStringSync();

    expect(settingsRepository, contains("'room_images_enabled': ?roomImagesEnabled"));
    expect(settingsRepository, contains("'guest_messages_enabled': ?guestMessagesEnabled"));
    expect(settingsRepository, contains("'apply_only_mode_enabled': ?applyOnlyModeEnabled"));
    expect(stateController, contains('roomImagesEnabled: value'));
    expect(stateController, contains('guestMessagesEnabled: value'));
    expect(stateController, contains('applyOnlyModeEnabled: value'));

    for (final retired in <String>[
      'setRoomImagesEnabled(bool enabled)',
      'setGuestMessagesEnabled(bool enabled)',
      'setRoomApplyOnlyMode(bool enabled)',
      'setRoomBackgroundTheme(String backgroundThemeId)',
      'setRoomAnnouncement(String announcementText)',
    ]) {
      expect(media, isNot(contains(retired)));
    }
  });

  test('Chunk 33 retired room compatibility files are removed', () {
    expect(
      File('lib/features/rooms/data/active_room_context.dart').existsSync(),
      isFalse,
    );
    expect(
      File('lib/features/rooms/data/room_seat_layout_sync_service.dart').existsSync(),
      isFalse,
    );
  });

}
