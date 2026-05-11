import 'package:flutter/foundation.dart';

class LiveRoomSettingsEventBus {
  LiveRoomSettingsEventBus._();

  static final ValueNotifier<LiveRoomSettingsEvent?> latestEvent = ValueNotifier<LiveRoomSettingsEvent?>(null);

  static void publish(LiveRoomSettingsEvent event) {
    latestEvent.value = event;
  }
}

class LiveRoomSettingsEvent {
  const LiveRoomSettingsEvent({
    required this.id,
    required this.roomId,
    required this.applyOnlyModeEnabled,
    required this.actorUserId,
    required this.actorName,
  });

  final String id;
  final String roomId;
  final bool applyOnlyModeEnabled;
  final String actorUserId;
  final String actorName;

  factory LiveRoomSettingsEvent.fromJson(Map<String, dynamic> json) {
    return LiveRoomSettingsEvent(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      roomId: json['room_id']?.toString() ?? '',
      applyOnlyModeEnabled: json['apply_only_mode_enabled'] == true || json['applyOnlyModeEnabled'] == true,
      actorUserId: json['actor_user_id']?.toString() ?? '',
      actorName: json['actor_name']?.toString() ?? '',
    );
  }
}
