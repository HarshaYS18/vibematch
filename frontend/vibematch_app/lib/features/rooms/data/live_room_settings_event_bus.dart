class LiveRoomSettingsEvent {
  const LiveRoomSettingsEvent({
    required this.id,
    required this.roomId,
    this.applyOnlyModeEnabled,
    this.roomImagesEnabled,
    this.guestMessagesEnabled,
    this.actorUserId = '',
    this.actorName = '',
    this.roomName = '',
    this.backgroundThemeId = '',
    this.seatLayoutId = '',
    this.announcementText = '',
    this.privacyModeTitle = '',
    this.allowScreenshots,
    this.language = '',
  });

  final String id;
  final String roomId;
  final bool? applyOnlyModeEnabled;
  final bool? roomImagesEnabled;
  final bool? guestMessagesEnabled;
  final String actorUserId;
  final String actorName;
  final String roomName;
  final String backgroundThemeId;
  final String seatLayoutId;
  final String announcementText;
  final String privacyModeTitle;
  final bool? allowScreenshots;
  final String language;

  factory LiveRoomSettingsEvent.fromJson(Map<String, dynamic> json) {
    final room = json['room'];
    final roomMap = room is Map<String, dynamic> ? room : <String, dynamic>{};

    return LiveRoomSettingsEvent(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      roomId: json['room_id']?.toString() ?? roomMap['room_id']?.toString() ?? roomMap['room_public_id']?.toString() ?? '',
      applyOnlyModeEnabled: _nullableBool(json['apply_only_mode_enabled'] ?? json['applyOnlyModeEnabled'] ?? roomMap['apply_only_mode_enabled'] ?? roomMap['applyOnlyModeEnabled']),
      roomImagesEnabled: _nullableBool(json['room_images_enabled'] ?? json['roomImagesEnabled'] ?? roomMap['room_images_enabled'] ?? roomMap['roomImagesEnabled']),
      guestMessagesEnabled: _nullableBool(json['guest_messages_enabled'] ?? json['guestMessagesEnabled'] ?? roomMap['guest_messages_enabled'] ?? roomMap['guestMessagesEnabled']),
      actorUserId: json['actor_user_id']?.toString() ?? '',
      actorName: json['actor_name']?.toString() ?? '',
      roomName: json['name']?.toString() ?? json['room_name']?.toString() ?? json['roomName']?.toString() ?? roomMap['name']?.toString() ?? roomMap['room_name']?.toString() ?? roomMap['roomName']?.toString() ?? '',
      backgroundThemeId: json['background_theme_id']?.toString() ?? json['backgroundThemeId']?.toString() ?? roomMap['background_theme_id']?.toString() ?? roomMap['backgroundThemeId']?.toString() ?? '',
      seatLayoutId: json['seat_layout_id']?.toString() ?? json['seatLayoutId']?.toString() ?? roomMap['seat_layout_id']?.toString() ?? roomMap['seatLayoutId']?.toString() ?? '',
      announcementText: json['announcement_text']?.toString() ?? json['announcementText']?.toString() ?? roomMap['announcement_text']?.toString() ?? roomMap['announcementText']?.toString() ?? '',
      privacyModeTitle: json['privacy_mode_title']?.toString() ?? json['privacyModeTitle']?.toString() ?? json['mode']?.toString() ?? roomMap['mode']?.toString() ?? '',
      allowScreenshots: _nullableBool(json['allow_screenshots'] ?? json['allowScreenshots'] ?? roomMap['allow_screenshots'] ?? roomMap['allowScreenshots']),
      language: json['language']?.toString() ?? roomMap['language']?.toString() ?? '',
    );
  }
}

bool? _nullableBool(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  final text = value.toString().trim().toLowerCase();
  if (text == 'true' || text == '1' || text == 'yes') return true;
  if (text == 'false' || text == '0' || text == 'no') return false;
  return null;
}
