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
    this.backgroundThemeId = '',
    this.announcementText = '',
  });

  final String id;
  final String roomId;
  final bool applyOnlyModeEnabled;
  final bool roomImagesEnabled;
  final bool guestMessagesEnabled;
  final String actorUserId;
  final String actorName;
  final String backgroundThemeId;
  final String announcementText;

  factory LiveRoomSettingsEvent.fromJson(Map<String, dynamic> json) {
    final room = json['room'];
    final roomMap = room is Map<String, dynamic> ? room : <String, dynamic>{};

    return LiveRoomSettingsEvent(
      id:
          json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      roomId: json['room_id']?.toString() ?? roomMap['room_id']?.toString() ?? '',
      applyOnlyModeEnabled:
          json['apply_only_mode_enabled'] == true ||
          json['applyOnlyModeEnabled'] == true ||
          roomMap['apply_only_mode_enabled'] == true ||
          roomMap['applyOnlyModeEnabled'] == true,
      roomImagesEnabled:
          json['room_images_enabled'] != false &&
          json['roomImagesEnabled'] != false &&
          roomMap['room_images_enabled'] != false &&
          roomMap['roomImagesEnabled'] != false,
      guestMessagesEnabled:
          json['guest_messages_enabled'] != false &&
          json['guestMessagesEnabled'] != false &&
          roomMap['guest_messages_enabled'] != false &&
          roomMap['guestMessagesEnabled'] != false,
      actorUserId: json['actor_user_id']?.toString() ?? '',
      actorName: json['actor_name']?.toString() ?? '',
      backgroundThemeId:
          json['background_theme_id']?.toString() ??
          json['backgroundThemeId']?.toString() ??
          roomMap['background_theme_id']?.toString() ??
          roomMap['backgroundThemeId']?.toString() ??
          '',
      announcementText:
          json['announcement_text']?.toString() ??
          json['announcementText']?.toString() ??
          roomMap['announcement_text']?.toString() ??
          roomMap['announcementText']?.toString() ??
          '',
    );
  }
}
