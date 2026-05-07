import 'package:shared_preferences/shared_preferences.dart';

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
    );
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
  }) {
    return AccountSettingsState(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      roomInvitesEnabled: roomInvitesEnabled ?? this.roomInvitesEnabled,
      strangerMessagesEnabled: strangerMessagesEnabled ?? this.strangerMessagesEnabled,
      mentionsEnabled: mentionsEnabled ?? this.mentionsEnabled,
      giftAlertsEnabled: giftAlertsEnabled ?? this.giftAlertsEnabled,
      eventAlertsEnabled: eventAlertsEnabled ?? this.eventAlertsEnabled,
      familyAlertsEnabled: familyAlertsEnabled ?? this.familyAlertsEnabled,
      adminSystemAlertsEnabled: adminSystemAlertsEnabled ?? this.adminSystemAlertsEnabled,
      floatingNotificationsEnabled: floatingNotificationsEnabled ?? this.floatingNotificationsEnabled,
      notificationSoundEnabled: notificationSoundEnabled ?? this.notificationSoundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      doNotDisturbEnabled: doNotDisturbEnabled ?? this.doNotDisturbEnabled,
      hideOnlineStatus: hideOnlineStatus ?? this.hideOnlineStatus,
      hideCurrentRoom: hideCurrentRoom ?? this.hideCurrentRoom,
      privateProfile: privateProfile ?? this.privateProfile,
      showLastSeen: showLastSeen ?? this.showLastSeen,
      showGiftStats: showGiftStats ?? this.showGiftStats,
      readReceiptsEnabled: readReceiptsEnabled ?? this.readReceiptsEnabled,
      allowStrangerMessages: allowStrangerMessages ?? this.allowStrangerMessages,
      anonymousChatroomAppearance: anonymousChatroomAppearance ?? this.anonymousChatroomAppearance,
      inboxLockEnabled: inboxLockEnabled ?? this.inboxLockEnabled,
      biometricUnlockEnabled: biometricUnlockEnabled ?? this.biometricUnlockEnabled,
      autoLockInbox: autoLockInbox ?? this.autoLockInbox,
      loginAlertsEnabled: loginAlertsEnabled ?? this.loginAlertsEnabled,
      hideSensitiveNotifications: hideSensitiveNotifications ?? this.hideSensitiveNotifications,
      autoJoinMicMuted: autoJoinMicMuted ?? this.autoJoinMicMuted,
      showEntranceEffects: showEntranceEffects ?? this.showEntranceEffects,
      imageMessagesEnabled: imageMessagesEnabled ?? this.imageMessagesEnabled,
      highQualityAnimations: highQualityAnimations ?? this.highQualityAnimations,
      dataSaverMode: dataSaverMode ?? this.dataSaverMode,
      ringtoneName: ringtoneName ?? this.ringtoneName,
      ringtonePath: clearRingtonePath ? null : ringtonePath ?? this.ringtonePath,
      notificationToneName: notificationToneName ?? this.notificationToneName,
      notificationTonePath: clearNotificationTonePath ? null : notificationTonePath ?? this.notificationTonePath,
    );
  }
}

class AccountSettingsStore {
  const AccountSettingsStore._();

  static const String _prefix = 'vm_account_settings.';

  static Future<AccountSettingsState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = AccountSettingsState.defaults();

    return AccountSettingsState(
      notificationsEnabled: prefs.getBool('${_prefix}notificationsEnabled') ?? defaults.notificationsEnabled,
      roomInvitesEnabled: prefs.getBool('${_prefix}roomInvitesEnabled') ?? defaults.roomInvitesEnabled,
      strangerMessagesEnabled: prefs.getBool('${_prefix}strangerMessagesEnabled') ?? defaults.strangerMessagesEnabled,
      mentionsEnabled: prefs.getBool('${_prefix}mentionsEnabled') ?? defaults.mentionsEnabled,
      giftAlertsEnabled: prefs.getBool('${_prefix}giftAlertsEnabled') ?? defaults.giftAlertsEnabled,
      eventAlertsEnabled: prefs.getBool('${_prefix}eventAlertsEnabled') ?? defaults.eventAlertsEnabled,
      familyAlertsEnabled: prefs.getBool('${_prefix}familyAlertsEnabled') ?? defaults.familyAlertsEnabled,
      adminSystemAlertsEnabled: prefs.getBool('${_prefix}adminSystemAlertsEnabled') ?? defaults.adminSystemAlertsEnabled,
      floatingNotificationsEnabled: prefs.getBool('${_prefix}floatingNotificationsEnabled') ?? defaults.floatingNotificationsEnabled,
      notificationSoundEnabled: prefs.getBool('${_prefix}notificationSoundEnabled') ?? defaults.notificationSoundEnabled,
      vibrationEnabled: prefs.getBool('${_prefix}vibrationEnabled') ?? defaults.vibrationEnabled,
      doNotDisturbEnabled: prefs.getBool('${_prefix}doNotDisturbEnabled') ?? defaults.doNotDisturbEnabled,
      hideOnlineStatus: prefs.getBool('${_prefix}hideOnlineStatus') ?? defaults.hideOnlineStatus,
      hideCurrentRoom: prefs.getBool('${_prefix}hideCurrentRoom') ?? defaults.hideCurrentRoom,
      privateProfile: prefs.getBool('${_prefix}privateProfile') ?? defaults.privateProfile,
      showLastSeen: prefs.getBool('${_prefix}showLastSeen') ?? defaults.showLastSeen,
      showGiftStats: prefs.getBool('${_prefix}showGiftStats') ?? defaults.showGiftStats,
      readReceiptsEnabled: prefs.getBool('${_prefix}readReceiptsEnabled') ?? defaults.readReceiptsEnabled,
      allowStrangerMessages: prefs.getBool('${_prefix}allowStrangerMessages') ?? defaults.allowStrangerMessages,
      anonymousChatroomAppearance: prefs.getBool('${_prefix}anonymousChatroomAppearance') ?? defaults.anonymousChatroomAppearance,
      inboxLockEnabled: prefs.getBool('${_prefix}inboxLockEnabled') ?? defaults.inboxLockEnabled,
      biometricUnlockEnabled: prefs.getBool('${_prefix}biometricUnlockEnabled') ?? defaults.biometricUnlockEnabled,
      autoLockInbox: prefs.getBool('${_prefix}autoLockInbox') ?? defaults.autoLockInbox,
      loginAlertsEnabled: prefs.getBool('${_prefix}loginAlertsEnabled') ?? defaults.loginAlertsEnabled,
      hideSensitiveNotifications: prefs.getBool('${_prefix}hideSensitiveNotifications') ?? defaults.hideSensitiveNotifications,
      autoJoinMicMuted: prefs.getBool('${_prefix}autoJoinMicMuted') ?? defaults.autoJoinMicMuted,
      showEntranceEffects: prefs.getBool('${_prefix}showEntranceEffects') ?? defaults.showEntranceEffects,
      imageMessagesEnabled: prefs.getBool('${_prefix}imageMessagesEnabled') ?? defaults.imageMessagesEnabled,
      highQualityAnimations: prefs.getBool('${_prefix}highQualityAnimations') ?? defaults.highQualityAnimations,
      dataSaverMode: prefs.getBool('${_prefix}dataSaverMode') ?? defaults.dataSaverMode,
      ringtoneName: prefs.getString('${_prefix}ringtoneName') ?? defaults.ringtoneName,
      ringtonePath: prefs.getString('${_prefix}ringtonePath'),
      notificationToneName: prefs.getString('${_prefix}notificationToneName') ?? defaults.notificationToneName,
      notificationTonePath: prefs.getString('${_prefix}notificationTonePath'),
    );
  }

  static Future<void> save(AccountSettingsState state) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('${_prefix}notificationsEnabled', state.notificationsEnabled);
    await prefs.setBool('${_prefix}roomInvitesEnabled', state.roomInvitesEnabled);
    await prefs.setBool('${_prefix}strangerMessagesEnabled', state.strangerMessagesEnabled);
    await prefs.setBool('${_prefix}mentionsEnabled', state.mentionsEnabled);
    await prefs.setBool('${_prefix}giftAlertsEnabled', state.giftAlertsEnabled);
    await prefs.setBool('${_prefix}eventAlertsEnabled', state.eventAlertsEnabled);
    await prefs.setBool('${_prefix}familyAlertsEnabled', state.familyAlertsEnabled);
    await prefs.setBool('${_prefix}adminSystemAlertsEnabled', state.adminSystemAlertsEnabled);
    await prefs.setBool('${_prefix}floatingNotificationsEnabled', state.floatingNotificationsEnabled);
    await prefs.setBool('${_prefix}notificationSoundEnabled', state.notificationSoundEnabled);
    await prefs.setBool('${_prefix}vibrationEnabled', state.vibrationEnabled);
    await prefs.setBool('${_prefix}doNotDisturbEnabled', state.doNotDisturbEnabled);
    await prefs.setBool('${_prefix}hideOnlineStatus', state.hideOnlineStatus);
    await prefs.setBool('${_prefix}hideCurrentRoom', state.hideCurrentRoom);
    await prefs.setBool('${_prefix}privateProfile', state.privateProfile);
    await prefs.setBool('${_prefix}showLastSeen', state.showLastSeen);
    await prefs.setBool('${_prefix}showGiftStats', state.showGiftStats);
    await prefs.setBool('${_prefix}readReceiptsEnabled', state.readReceiptsEnabled);
    await prefs.setBool('${_prefix}allowStrangerMessages', state.allowStrangerMessages);
    await prefs.setBool('${_prefix}anonymousChatroomAppearance', state.anonymousChatroomAppearance);
    await prefs.setBool('${_prefix}inboxLockEnabled', state.inboxLockEnabled);
    await prefs.setBool('${_prefix}biometricUnlockEnabled', state.biometricUnlockEnabled);
    await prefs.setBool('${_prefix}autoLockInbox', state.autoLockInbox);
    await prefs.setBool('${_prefix}loginAlertsEnabled', state.loginAlertsEnabled);
    await prefs.setBool('${_prefix}hideSensitiveNotifications', state.hideSensitiveNotifications);
    await prefs.setBool('${_prefix}autoJoinMicMuted', state.autoJoinMicMuted);
    await prefs.setBool('${_prefix}showEntranceEffects', state.showEntranceEffects);
    await prefs.setBool('${_prefix}imageMessagesEnabled', state.imageMessagesEnabled);
    await prefs.setBool('${_prefix}highQualityAnimations', state.highQualityAnimations);
    await prefs.setBool('${_prefix}dataSaverMode', state.dataSaverMode);
    await prefs.setString('${_prefix}ringtoneName', state.ringtoneName);
    await _setNullableString(prefs, '${_prefix}ringtonePath', state.ringtonePath);
    await prefs.setString('${_prefix}notificationToneName', state.notificationToneName);
    await _setNullableString(prefs, '${_prefix}notificationTonePath', state.notificationTonePath);
  }

  static Future<void> reset() async {
    await save(AccountSettingsState.defaults());
  }

  static Future<void> _setNullableString(SharedPreferences prefs, String key, String? value) async {
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, value);
  }
}
