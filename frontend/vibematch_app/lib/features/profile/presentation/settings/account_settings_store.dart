import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/network/vm_api_config.dart';
import '../../../auth/data/auth_api_service.dart';

class AccountSettingsState {
  const AccountSettingsState({
    required this.notificationsEnabled,
    required this.roomInvitesEnabled,
    required this.strangerMessagesEnabled,
    required this.mentionsEnabled,
    required this.giftAlertsEnabled,
    required this.eventAlertsEnabled,
    required this.familyAlertsEnabled,
    required this.adminSystemAlertsEnabled,
    required this.floatingNotificationsEnabled,
    required this.notificationSoundEnabled,
    required this.vibrationEnabled,
    required this.doNotDisturbEnabled,
    required this.hideOnlineStatus,
    required this.hideCurrentRoom,
    required this.privateProfile,
    required this.showLastSeen,
    required this.showGiftStats,
    required this.readReceiptsEnabled,
    required this.allowStrangerMessages,
    required this.anonymousChatroomAppearance,
    required this.inboxLockEnabled,
    required this.biometricUnlockEnabled,
    required this.autoLockInbox,
    required this.loginAlertsEnabled,
    required this.hideSensitiveNotifications,
    required this.autoJoinMicMuted,
    required this.showEntranceEffects,
    required this.imageMessagesEnabled,
    required this.highQualityAnimations,
    required this.dataSaverMode,
    required this.ringtoneName,
    required this.ringtonePath,
    required this.notificationToneName,
    required this.notificationTonePath,
    required this.language,
    required this.appearance,
    required this.chatWallpaper,
    required this.deviceTrustEnabled,
  });

  final bool notificationsEnabled;
  final bool roomInvitesEnabled;
  final bool strangerMessagesEnabled;
  final bool mentionsEnabled;
  final bool giftAlertsEnabled;
  final bool eventAlertsEnabled;
  final bool familyAlertsEnabled;
  final bool adminSystemAlertsEnabled;
  final bool floatingNotificationsEnabled;
  final bool notificationSoundEnabled;
  final bool vibrationEnabled;
  final bool doNotDisturbEnabled;
  final bool hideOnlineStatus;
  final bool hideCurrentRoom;
  final bool privateProfile;
  final bool showLastSeen;
  final bool showGiftStats;
  final bool readReceiptsEnabled;
  final bool allowStrangerMessages;
  final bool anonymousChatroomAppearance;
  final bool inboxLockEnabled;
  final bool biometricUnlockEnabled;
  final bool autoLockInbox;
  final bool loginAlertsEnabled;
  final bool hideSensitiveNotifications;
  final bool autoJoinMicMuted;
  final bool showEntranceEffects;
  final bool imageMessagesEnabled;
  final bool highQualityAnimations;
  final bool dataSaverMode;
  final String ringtoneName;
  final String? ringtonePath;
  final String notificationToneName;
  final String? notificationTonePath;
  final String language;
  final String appearance;
  final String chatWallpaper;
  final bool deviceTrustEnabled;

  factory AccountSettingsState.defaults() {
    return const AccountSettingsState(
      notificationsEnabled: true,
      roomInvitesEnabled: true,
      strangerMessagesEnabled: true,
      mentionsEnabled: true,
      giftAlertsEnabled: true,
      eventAlertsEnabled: true,
      familyAlertsEnabled: true,
      adminSystemAlertsEnabled: true,
      floatingNotificationsEnabled: true,
      notificationSoundEnabled: true,
      vibrationEnabled: true,
      doNotDisturbEnabled: false,
      hideOnlineStatus: false,
      hideCurrentRoom: false,
      privateProfile: false,
      showLastSeen: true,
      showGiftStats: true,
      readReceiptsEnabled: true,
      allowStrangerMessages: true,
      anonymousChatroomAppearance: false,
      inboxLockEnabled: false,
      biometricUnlockEnabled: false,
      autoLockInbox: true,
      loginAlertsEnabled: true,
      hideSensitiveNotifications: true,
      autoJoinMicMuted: true,
      showEntranceEffects: true,
      imageMessagesEnabled: true,
      highQualityAnimations: true,
      dataSaverMode: false,
      ringtoneName: 'Vibe Classic Ring',
      ringtonePath: null,
      notificationToneName: 'Soft Vibe Ping',
      notificationTonePath: null,
      language: 'English',
      appearance: 'System',
      chatWallpaper: 'Pearl',
      deviceTrustEnabled: true,
    );
  }

  factory AccountSettingsState.fromJson(Map<String, dynamic> json) {
    final defaults = AccountSettingsState.defaults();
    return AccountSettingsState(
      notificationsEnabled: _bool(
        json['notifications_enabled'],
        defaults.notificationsEnabled,
      ),
      roomInvitesEnabled: _bool(
        json['room_invites_enabled'],
        defaults.roomInvitesEnabled,
      ),
      strangerMessagesEnabled: _bool(
        json['stranger_messages_enabled'],
        defaults.strangerMessagesEnabled,
      ),
      mentionsEnabled: _bool(
        json['mentions_enabled'],
        defaults.mentionsEnabled,
      ),
      giftAlertsEnabled: _bool(
        json['gift_alerts_enabled'],
        defaults.giftAlertsEnabled,
      ),
      eventAlertsEnabled: _bool(
        json['event_alerts_enabled'],
        defaults.eventAlertsEnabled,
      ),
      familyAlertsEnabled: _bool(
        json['family_alerts_enabled'],
        defaults.familyAlertsEnabled,
      ),
      adminSystemAlertsEnabled: _bool(
        json['admin_system_alerts_enabled'],
        defaults.adminSystemAlertsEnabled,
      ),
      floatingNotificationsEnabled: _bool(
        json['floating_notifications_enabled'],
        defaults.floatingNotificationsEnabled,
      ),
      notificationSoundEnabled: _bool(
        json['notification_sound_enabled'],
        defaults.notificationSoundEnabled,
      ),
      vibrationEnabled: _bool(
        json['vibration_enabled'],
        defaults.vibrationEnabled,
      ),
      doNotDisturbEnabled: _bool(
        json['do_not_disturb_enabled'],
        defaults.doNotDisturbEnabled,
      ),
      hideOnlineStatus: _bool(
        json['hide_online_status'],
        defaults.hideOnlineStatus,
      ),
      hideCurrentRoom: _bool(
        json['hide_current_room'],
        defaults.hideCurrentRoom,
      ),
      privateProfile: _bool(json['private_profile'], defaults.privateProfile),
      showLastSeen: _bool(json['show_last_seen'], defaults.showLastSeen),
      showGiftStats: _bool(json['show_gift_stats'], defaults.showGiftStats),
      readReceiptsEnabled: _bool(
        json['read_receipts_enabled'],
        defaults.readReceiptsEnabled,
      ),
      allowStrangerMessages: _bool(
        json['allow_stranger_messages'],
        defaults.allowStrangerMessages,
      ),
      anonymousChatroomAppearance: _bool(
        json['anonymous_chatroom_appearance'],
        defaults.anonymousChatroomAppearance,
      ),
      inboxLockEnabled: _bool(
        json['inbox_lock_enabled'],
        defaults.inboxLockEnabled,
      ),
      biometricUnlockEnabled: _bool(
        json['biometric_unlock_enabled'],
        defaults.biometricUnlockEnabled,
      ),
      autoLockInbox: _bool(json['auto_lock_inbox'], defaults.autoLockInbox),
      loginAlertsEnabled: _bool(
        json['login_alerts_enabled'],
        defaults.loginAlertsEnabled,
      ),
      hideSensitiveNotifications: _bool(
        json['hide_sensitive_notifications'],
        defaults.hideSensitiveNotifications,
      ),
      autoJoinMicMuted: _bool(
        json['auto_join_mic_muted'],
        defaults.autoJoinMicMuted,
      ),
      showEntranceEffects: _bool(
        json['show_entrance_effects'],
        defaults.showEntranceEffects,
      ),
      imageMessagesEnabled: _bool(
        json['image_messages_enabled'],
        defaults.imageMessagesEnabled,
      ),
      highQualityAnimations: _bool(
        json['high_quality_animations'],
        defaults.highQualityAnimations,
      ),
      dataSaverMode: _bool(json['data_saver_mode'], defaults.dataSaverMode),
      ringtoneName: json['ringtone_name']?.toString() ?? defaults.ringtoneName,
      ringtonePath: _nullableString(json['ringtone_path']),
      notificationToneName:
          json['notification_tone_name']?.toString() ??
          defaults.notificationToneName,
      notificationTonePath: _nullableString(json['notification_tone_path']),
      language: json['language']?.toString() ?? defaults.language,
      appearance: json['appearance']?.toString() ?? defaults.appearance,
      chatWallpaper:
          json['chat_wallpaper']?.toString() ?? defaults.chatWallpaper,
      deviceTrustEnabled: _bool(
        json['device_trust_enabled'],
        defaults.deviceTrustEnabled,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'notifications_enabled': notificationsEnabled,
      'room_invites_enabled': roomInvitesEnabled,
      'stranger_messages_enabled': strangerMessagesEnabled,
      'mentions_enabled': mentionsEnabled,
      'gift_alerts_enabled': giftAlertsEnabled,
      'event_alerts_enabled': eventAlertsEnabled,
      'family_alerts_enabled': familyAlertsEnabled,
      'admin_system_alerts_enabled': adminSystemAlertsEnabled,
      'floating_notifications_enabled': floatingNotificationsEnabled,
      'notification_sound_enabled': notificationSoundEnabled,
      'vibration_enabled': vibrationEnabled,
      'do_not_disturb_enabled': doNotDisturbEnabled,
      'hide_online_status': hideOnlineStatus,
      'hide_current_room': hideCurrentRoom,
      'private_profile': privateProfile,
      'show_last_seen': showLastSeen,
      'show_gift_stats': showGiftStats,
      'read_receipts_enabled': readReceiptsEnabled,
      'allow_stranger_messages': allowStrangerMessages,
      'anonymous_chatroom_appearance': anonymousChatroomAppearance,
      'inbox_lock_enabled': inboxLockEnabled,
      'biometric_unlock_enabled': biometricUnlockEnabled,
      'auto_lock_inbox': autoLockInbox,
      'login_alerts_enabled': loginAlertsEnabled,
      'hide_sensitive_notifications': hideSensitiveNotifications,
      'auto_join_mic_muted': autoJoinMicMuted,
      'show_entrance_effects': showEntranceEffects,
      'image_messages_enabled': imageMessagesEnabled,
      'high_quality_animations': highQualityAnimations,
      'data_saver_mode': dataSaverMode,
      'ringtone_name': ringtoneName,
      'ringtone_path': ringtonePath,
      'notification_tone_name': notificationToneName,
      'notification_tone_path': notificationTonePath,
      'language': language,
      'appearance': appearance,
      'chat_wallpaper': chatWallpaper,
      'device_trust_enabled': deviceTrustEnabled,
    };
  }

  AccountSettingsState copyWith({
    bool? notificationsEnabled,
    bool? roomInvitesEnabled,
    bool? strangerMessagesEnabled,
    bool? mentionsEnabled,
    bool? giftAlertsEnabled,
    bool? eventAlertsEnabled,
    bool? familyAlertsEnabled,
    bool? adminSystemAlertsEnabled,
    bool? floatingNotificationsEnabled,
    bool? notificationSoundEnabled,
    bool? vibrationEnabled,
    bool? doNotDisturbEnabled,
    bool? hideOnlineStatus,
    bool? hideCurrentRoom,
    bool? privateProfile,
    bool? showLastSeen,
    bool? showGiftStats,
    bool? readReceiptsEnabled,
    bool? allowStrangerMessages,
    bool? anonymousChatroomAppearance,
    bool? inboxLockEnabled,
    bool? biometricUnlockEnabled,
    bool? autoLockInbox,
    bool? loginAlertsEnabled,
    bool? hideSensitiveNotifications,
    bool? autoJoinMicMuted,
    bool? showEntranceEffects,
    bool? imageMessagesEnabled,
    bool? highQualityAnimations,
    bool? dataSaverMode,
    String? ringtoneName,
    String? ringtonePath,
    bool clearRingtonePath = false,
    String? notificationToneName,
    String? notificationTonePath,
    bool clearNotificationTonePath = false,
    String? language,
    String? appearance,
    String? chatWallpaper,
    bool? deviceTrustEnabled,
  }) {
    return AccountSettingsState(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      roomInvitesEnabled: roomInvitesEnabled ?? this.roomInvitesEnabled,
      strangerMessagesEnabled:
          strangerMessagesEnabled ?? this.strangerMessagesEnabled,
      mentionsEnabled: mentionsEnabled ?? this.mentionsEnabled,
      giftAlertsEnabled: giftAlertsEnabled ?? this.giftAlertsEnabled,
      eventAlertsEnabled: eventAlertsEnabled ?? this.eventAlertsEnabled,
      familyAlertsEnabled: familyAlertsEnabled ?? this.familyAlertsEnabled,
      adminSystemAlertsEnabled:
          adminSystemAlertsEnabled ?? this.adminSystemAlertsEnabled,
      floatingNotificationsEnabled:
          floatingNotificationsEnabled ?? this.floatingNotificationsEnabled,
      notificationSoundEnabled:
          notificationSoundEnabled ?? this.notificationSoundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      doNotDisturbEnabled: doNotDisturbEnabled ?? this.doNotDisturbEnabled,
      hideOnlineStatus: hideOnlineStatus ?? this.hideOnlineStatus,
      hideCurrentRoom: hideCurrentRoom ?? this.hideCurrentRoom,
      privateProfile: privateProfile ?? this.privateProfile,
      showLastSeen: showLastSeen ?? this.showLastSeen,
      showGiftStats: showGiftStats ?? this.showGiftStats,
      readReceiptsEnabled: readReceiptsEnabled ?? this.readReceiptsEnabled,
      allowStrangerMessages:
          allowStrangerMessages ?? this.allowStrangerMessages,
      anonymousChatroomAppearance:
          anonymousChatroomAppearance ?? this.anonymousChatroomAppearance,
      inboxLockEnabled: inboxLockEnabled ?? this.inboxLockEnabled,
      biometricUnlockEnabled:
          biometricUnlockEnabled ?? this.biometricUnlockEnabled,
      autoLockInbox: autoLockInbox ?? this.autoLockInbox,
      loginAlertsEnabled: loginAlertsEnabled ?? this.loginAlertsEnabled,
      hideSensitiveNotifications:
          hideSensitiveNotifications ?? this.hideSensitiveNotifications,
      autoJoinMicMuted: autoJoinMicMuted ?? this.autoJoinMicMuted,
      showEntranceEffects: showEntranceEffects ?? this.showEntranceEffects,
      imageMessagesEnabled: imageMessagesEnabled ?? this.imageMessagesEnabled,
      highQualityAnimations:
          highQualityAnimations ?? this.highQualityAnimations,
      dataSaverMode: dataSaverMode ?? this.dataSaverMode,
      ringtoneName: ringtoneName ?? this.ringtoneName,
      ringtonePath: clearRingtonePath
          ? null
          : ringtonePath ?? this.ringtonePath,
      notificationToneName: notificationToneName ?? this.notificationToneName,
      notificationTonePath: clearNotificationTonePath
          ? null
          : notificationTonePath ?? this.notificationTonePath,
      language: language ?? this.language,
      appearance: appearance ?? this.appearance,
      chatWallpaper: chatWallpaper ?? this.chatWallpaper,
      deviceTrustEnabled: deviceTrustEnabled ?? this.deviceTrustEnabled,
    );
  }

  static bool _bool(Object? value, bool fallback) =>
      value is bool ? value : fallback;

  static String? _nullableString(Object? value) {
    final text = value?.toString();
    if (text == null || text.trim().isEmpty) return null;
    return text;
  }
}

class AccountSettingsStore {
  const AccountSettingsStore._();

  static Future<AccountSettingsState> load() async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/settings/me')),
      headers: _headers(),
    );
    _throwIfFailed(response, 'load account settings');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map)
      throw Exception('Settings returned an unexpected response.');
    final settings = decoded['settings'];
    if (settings is! Map) throw Exception('Settings response is missing data.');
    return AccountSettingsState.fromJson(Map<String, dynamic>.from(settings));
  }

  static Future<void> save(AccountSettingsState state) async {
    final response = await http.put(
      Uri.parse(VmApiConfig.endpoint('/settings/me')),
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{'settings': state.toJson()}),
    );
    _throwIfFailed(response, 'save account settings');
  }

  static Future<void> reset() async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/settings/me/reset')),
      headers: _headers(),
    );
    _throwIfFailed(response, 'reset account settings');
  }

  static Future<List<BlockedUserSetting>> loadBlockedUsers() async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/settings/blocked-users')),
      headers: _headers(),
    );
    _throwIfFailed(response, 'load blocked users');
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const <BlockedUserSetting>[];
    return decoded
        .whereType<Map>()
        .map(
          (item) =>
              BlockedUserSetting.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  static Future<List<BlockedUserSetting>> unblockUser(int publicUserId) async {
    final response = await http.delete(
      Uri.parse(VmApiConfig.endpoint('/settings/blocked-users/$publicUserId')),
      headers: _headers(),
    );
    _throwIfFailed(response, 'unblock user');
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const <BlockedUserSetting>[];
    return decoded
        .whereType<Map>()
        .map(
          (item) =>
              BlockedUserSetting.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  static Map<String, String> _headers() {
    final token = const AuthApiService().cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Log in to manage settings.');
    }
    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static void _throwIfFailed(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var detail = 'Could not $action.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        detail = decoded['detail'].toString();
      }
    } catch (_) {
      // Keep the production-safe fallback.
    }
    throw Exception(detail);
  }
}

class BlockedUserSetting {
  const BlockedUserSetting({
    required this.publicUserId,
    required this.displayName,
    this.username,
    this.avatarUrl,
  });

  final int publicUserId;
  final String displayName;
  final String? username;
  final String? avatarUrl;

  factory BlockedUserSetting.fromJson(Map<String, dynamic> json) {
    return BlockedUserSetting(
      publicUserId: int.tryParse(json['public_user_id']?.toString() ?? '') ?? 0,
      displayName: json['display_name']?.toString() ?? 'Blocked user',
      username: json['username']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}
