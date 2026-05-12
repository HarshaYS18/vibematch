import 'package:flutter/foundation.dart';

class LiveRoomSettingsEventBus {
  LiveRoomSettingsEventBus._();

  static final ValueNotifier<LiveRoomSettingsEvent?> latestEvent =
      ValueNotifier<LiveRoomSettingsEvent?>(null);

  static void publish(LiveRoomSettingsEvent event) {
    latestEvent.value = event;
  }
}

class LiveRoomSettingsEvent {
  const LiveRoomSettingsEvent({
    required this.id,
    required this.roomId,
    required this.applyOnlyModeEnabled,
    required this.roomImagesEnabled,
    required this.guestMessagesEnabled,
    required this.actorUserId,
    required this.actorName,
  });

  final String id;
  final String roomId;
  final bool applyOnlyModeEnabled;
  final bool roomImagesEnabled;
  final bool guestMessagesEnabled;
  final String actorUserId;
  final String actorName;

  factory LiveRoomSettingsEvent.fromJson(Map<String, dynamic> json) {
    return LiveRoomSettingsEvent(
      id:
          json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      roomId: json['room_id']?.toString() ?? '',
      applyOnlyModeEnabled:
          json['apply_only_mode_enabled'] == true ||
          json['applyOnlyModeEnabled'] == true,
      roomImagesEnabled:
          json['room_images_enabled'] != false &&
          json['roomImagesEnabled'] != false,
      guestMessagesEnabled:
          json['guest_messages_enabled'] != false &&
          json['guestMessagesEnabled'] != false,
      actorUserId: json['actor_user_id']?.toString() ?? '',
      actorName: json['actor_name']?.toString() ?? '',
    );
  }
}
