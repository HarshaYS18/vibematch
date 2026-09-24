import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inbox and wallet no longer create their own app websockets', () {
    final inbox = File(
      'lib/features/inbox/data/inbox_socket_service.dart',
    ).readAsStringSync();
    final wallet = File(
      'lib/features/wallet/data/wallet_realtime_sync_service.dart',
    ).readAsStringSync();
    final client = File(
      'lib/foundation/realtime/realtime_client.dart',
    ).readAsStringSync();

    expect(inbox, isNot(contains('WebSocketChannel.connect')));
    expect(wallet, isNot(contains('WebSocketChannel.connect')));
    expect(inbox, contains('AppRealtimeHub'));
    expect(client, contains('WebSocketChannel.connect'));
  });
  test('Go socket lease is the only first-party online liveness writer', () {
    final shell = File('lib/app/app_shell.dart').readAsStringSync();
    final roomShell = File(
      'lib/features/rooms/presentation/live_room_presence_shell_page.dart',
    ).readAsStringSync();
    final roomRepository = File(
      'lib/room_session/data/room_session_repository.dart',
    ).readAsStringSync();
    final presenceApi = File(
      'lib/features/presence/data/presence_api_service.dart',
    ).readAsStringSync();

    expect(shell, isNot(contains('AppPresenceRuntime')));
    expect(shell, isNot(contains('appPresenceRuntimeProvider')));
    expect(roomShell, isNot(contains('Duration(seconds: 12)')));
    expect(roomShell, isNot(contains('_heartbeatTimer')));
    expect(roomRepository, isNot(contains('/realtime/heartbeat')));
    expect(presenceApi, isNot(contains('/presence/heartbeat')));
    expect(presenceApi, isNot(contains('/presence/room/enter')));
    expect(presenceApi, isNot(contains('/presence/room/leave')));
  });

}
