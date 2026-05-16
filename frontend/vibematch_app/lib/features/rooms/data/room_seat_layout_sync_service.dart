import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/vm_media_config.dart';

class RoomSeatLayoutSyncService {
  const RoomSeatLayoutSyncService._();

  static Future<void> broadcastSeatLayout({
    required String roomId,
    required String seatLayoutId,
  }) async {
    final safeRoomId = roomId.trim();
    final safeLayout = seatLayoutId.trim();
    if (safeRoomId.isEmpty || safeLayout.isEmpty) return;

    WebSocketChannel? channel;
    try {
      channel = WebSocketChannel.connect(Uri.parse(VmMediaConfig.wsUrl));
      channel.sink.add(
        jsonEncode({
          'type': 'room_settings/seat_layout',
          'payload': {
            'room_id': safeRoomId,
            'seat_layout_id': safeLayout,
          },
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 160));
    } catch (_) {
      // Realtime broadcast is best-effort. Backend persistence remains source of truth.
    } finally {
      unawaited(channel?.sink.close());
    }
  }
}
