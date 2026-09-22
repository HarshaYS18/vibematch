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
}
