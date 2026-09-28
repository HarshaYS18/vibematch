import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/network/vm_failure.dart';
import '../../../../core/presentation/vm_async_state.dart';

import 'account_settings_store.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key, required this.svipLevel});

  final int svipLevel;

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  AccountSettingsState? _state;
  String? _loadError;
  bool _saving = false;

  bool get _hasSvipAnonymousAccess => widget.svipLevel > 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final state = await AccountSettingsStore.load();
      if (!mounted) return;
      setState(() {
        _state = state;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = VmFailurePresentation.messageFor(error, contentLabel: 'account settings'));
    }
  }

  Future<void> _update(
    AccountSettingsState Function(AccountSettingsState current) update,
  ) async {
    final current = _state;
    if (current == null || _saving) return;

    final next = update(current);
    setState(() {
      _state = next;
      _saving = true;
    });

    try {
      await AccountSettingsStore.save(next);
    } catch (error) {
      if (mounted) {
        _toast(VmFailurePresentation.messageFor(error, contentLabel: 'account settings'));
        setState(() => _state = current);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
  }

  Future<void> _resetSettings() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmResetSheet(
        onCancel: () => Navigator.pop(context, false),
        onReset: () => Navigator.pop(context, true),
      ),
    );

    if (confirmed != true) return;
    try {
      await AccountSettingsStore.reset();
      await _loadSettings();
      if (mounted) _toast('Settings reset to default.');
    } catch (error) {
      if (mounted) _toast(VmFailurePresentation.messageFor(error, contentLabel: 'account settings'));
    }
  }

  Future<void> _pickTone({required bool ringtone}) async {
    final current = _state;
    if (current == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'aac', 'wav', 'ogg'],
      allowMultiple: false,
      withData: false,
    );
    final file = result?.files.single;
    if (file == null) return;

    await _update((state) {
      if (ringtone) {
        return state.copyWith(ringtoneName: file.name, ringtonePath: file.path);
      }
      return state.copyWith(
        notificationToneName: file.name,
        notificationTonePath: file.path,
      );
    });

    _toast(ringtone ? 'Ringtone updated.' : 'Notification tone updated.');
  }

  Future<void> _chooseBuiltInTone({
    required bool ringtone,
    required String name,
  }) async {
    await _update((state) {
      if (ringtone) {
        return state.copyWith(ringtoneName: name, clearRingtonePath: true);
      }
      return state.copyWith(
        notificationToneName: name,
        clearNotificationTonePath: true,
      );
    });
  }

  void _showToneSheet({required bool ringtone}) {
    final state = _state;
    if (state == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TonePickerSheet(
        title: ringtone ? 'Set ringtone' : 'Set notification tone',
        selectedName: ringtone
            ? state.ringtoneName
            : state.notificationToneName,
        builtInTones: ringtone ? _builtInRingtones : _builtInNotificationTones,
        onBuiltInSelected: (name) async {
          Navigator.pop(context);
          await _chooseBuiltInTone(ringtone: ringtone, name: name);
        },
        onPickFile: () async {
          Navigator.pop(context);
          await _pickTone(ringtone: ringtone);
        },
      ),
    );
  }

  void _toggleAnonymousAppearance(bool value) {
    if (value && !_hasSvipAnonymousAccess) {
      _toast('Anonymous chatroom appearance is an SVIP feature.');
      return;
    }
    _update((state) => state.copyWith(anonymousChatroomAppearance: value));
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Column(
          children: [
            _SettingsHeader(
              saving: _saving,
              onBack: () => Navigator.pop(context),
              onReset: _resetSettings,
            ),
            if (_loadError != null)
              Expanded(
                child: VmFailureState(
                  message: _loadError!,
                  contentLabel: 'account settings',
                  onRetry: _loadSettings,
                ),
              )
            else if (state == null)
              const Expanded(
                child: VmLoadingState(message: 'Loading account settings…'),
              )
            else
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _SettingsHeroCard(
                      notificationsEnabled: state.notificationsEnabled,
                      anonymousEnabled: state.anonymousChatroomAppearance,
                      ringtoneName: state.ringtoneName,
                      notificationToneName: state.notificationToneName,
                    ),
                    const SizedBox(height: 12),
                    _SettingsSection(
                      title: 'Notifications',
                      subtitle:
                          'Controls alerts, room invites, system messages, sounds and vibration.',
                      children: [
                        _SwitchRow(
                          title: 'All notifications',
                          subtitle: 'Master switch for app notifications.',
                          icon: Icons.notifications_active_rounded,
                          value: state.notificationsEnabled,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(notificationsEnabled: value),
                          ),
                        ),
                        _SwitchRow(
                          title: 'Room invites',
                          subtitle:
                              'Inbox and floating alerts for chatroom invites.',
                          icon: Icons.mark_email_unread_rounded,
                          value: state.roomInvitesEnabled,
                          enabled: state.notificationsEnabled,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(roomInvitesEnabled: value),
                          ),
                        ),
                        _SwitchRow(
                          title: 'Stranger messages',
                          subtitle: 'Alerts for non-mutual user messages.',
                          icon: Icons.person_add_alt_1_rounded,
                          value: state.strangerMessagesEnabled,
                          enabled: state.notificationsEnabled,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(strangerMessagesEnabled: value),
                          ),
                        ),
                        _SwitchRow(
                          title: 'Mentions and tags',
                          subtitle: 'Alerts for @mentions, @all and reactions.',
                          icon: Icons.alternate_email_rounded,
                          value: state.mentionsEnabled,
                          enabled: state.notificationsEnabled,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(mentionsEnabled: value),
                          ),
                        ),
                        _SwitchRow(
                          title: 'Gift alerts',
                          subtitle:
                              'Alerts for gift receives, lucky packets and premium gifts.',
                          icon: Icons.card_giftcard_rounded,
                          value: state.giftAlertsEnabled,
                          enabled: state.notificationsEnabled,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(giftAlertsEnabled: value),
                          ),
                        ),
                        _SwitchRow(
                          title: 'Events and family alerts',
                          subtitle:
                              'Family events, app events, ranking and reward notices.',
                          icon: Icons.emoji_events_rounded,
                          value:
                              state.eventAlertsEnabled &&
                              state.familyAlertsEnabled,
                          enabled: state.notificationsEnabled,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(
                              eventAlertsEnabled: value,
                              familyAlertsEnabled: value,
                            ),
                          ),
                        ),
                        _SwitchRow(
                          title: 'Official/system alerts',
                          subtitle:
                              'Vibe Match Team, moderation, security and payout notices.',
                          icon: Icons.verified_user_rounded,
                          value: state.adminSystemAlertsEnabled,
                          enabled: state.notificationsEnabled,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(adminSystemAlertsEnabled: value),
                          ),
                        ),
                        _SwitchRow(
                          title: 'Floating notifications',
                          subtitle:
                              'Realtime overlay alerts while using the app.',
                          icon: Icons.open_in_new_rounded,
                          value: state.floatingNotificationsEnabled,
                          enabled: state.notificationsEnabled,
                          onChanged: (value) => _update(
                            (s) =>
                                s.copyWith(floatingNotificationsEnabled: value),
                          ),
                        ),
                        _SwitchRow(
                          title: 'Notification sound',
                          subtitle: 'Play tone when alerts arrive.',
                          icon: Icons.volume_up_rounded,
                          value: state.notificationSoundEnabled,
                          enabled: state.notificationsEnabled,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(notificationSoundEnabled: value),
                          ),
                        ),
                        _SwitchRow(
                          title: 'Vibration',
                          subtitle: 'Vibrate for supported alerts.',
                          icon: Icons.vibration_rounded,
                          value: state.vibrationEnabled,
                          enabled: state.notificationsEnabled,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(vibrationEnabled: value),
                          ),
                        ),
                        _SwitchRow(
                          title: 'Do not disturb',
                          subtitle:
                              'Silence normal alerts. System/security alerts remain allowed.',
                          icon: Icons.do_not_disturb_on_rounded,
                          value: state.doNotDisturbEnabled,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(doNotDisturbEnabled: value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SettingsSection(
                      title: 'Tones',
                      subtitle:
                          'Choose built-in tones or pick an audio file from your device.',
                      children: [
                        _ActionRow(
                          title: 'Ringtone',
                          subtitle: state.ringtoneName,
                          icon: Icons.ring_volume_rounded,
                          onTap: () => _showToneSheet(ringtone: true),
                        ),
                        _ActionRow(
                          title: 'Notification tone',
                          subtitle: state.notificationToneName,
                          icon: Icons.notifications_rounded,
                          onTap: () => _showToneSheet(ringtone: false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SettingsSection(
                      title: 'Privacy and profile',
                      subtitle:
                          'Presence, room visibility, profile access, stats and chat privacy.',
                      children: [
                        _SwitchRow(
                          title: 'Hide online status',
                          subtitle:
                              'Show you as offline/idle where privacy rules allow.',
                          icon: Icons.visibility_off_rounded,
                          value: state.hideOnlineStatus,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(hideOnlineStatus: value),
                          ),
                        ),
                        _SwitchRow(
                          title: 'Hide current room',
                          subtitle:
                              'Do not show which chatroom you are inside.',
                          icon: Icons.meeting_room_rounded,
                          value: state.hideCurrentRoom,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(hideCurrentRoom: value),
                          ),
                        ),
                        _SwitchRow(
                          title: 'Private profile',
                          subtitle:
                              'Require follow/mutual visibility for sensitive profile parts.',
                          icon: Icons.lock_person_rounded,
                          value: state.privateProfile,
                          onChanged: (value) =>
                              _update((s) => s.copyWith(privateProfile: value)),
                        ),
                        _SwitchRow(
                          title: 'Show last seen',
                          subtitle:
                              'Allow others to see your last active time.',
                          icon: Icons.schedule_rounded,
                          value: state.showLastSeen,
                          onChanged: (value) =>
                              _update((s) => s.copyWith(showLastSeen: value)),
                        ),
                        _SwitchRow(
                          title: 'Show gift stats',
                          subtitle:
                              'Show sent/received contribution stats on profile.',
                          icon: Icons.diamond_rounded,
                          value: state.showGiftStats,
                          onChanged: (value) =>
                              _update((s) => s.copyWith(showGiftStats: value)),
                        ),
                        _SwitchRow(
                          title: 'Read receipts',
                          subtitle: 'Show seen/read status in supported chats.',
                          icon: Icons.done_all_rounded,
                          value: state.readReceiptsEnabled,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(readReceiptsEnabled: value),
                          ),
                        ),
                        _SwitchRow(
                          title: 'Allow stranger messages',
                          subtitle:
                              'Let non-mutual users send Stranger Messages.',
                          icon: Icons.forum_rounded,
                          value: state.allowStrangerMessages,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(allowStrangerMessages: value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SettingsSection(
                      title: 'Chatroom appearance',
                      subtitle:
                          'Controls how you appear and behave inside rooms.',
                      children: [
                        _SwitchRow(
                          title: 'Anonymous appearance',
                          subtitle: _hasSvipAnonymousAccess
                              ? 'SVIP mode: hide public identity in chatrooms.'
                              : 'SVIP feature required.',
                          icon: Icons.masks_rounded,
                          value: state.anonymousChatroomAppearance,
                          premium: true,
                          onChanged: _toggleAnonymousAppearance,
                        ),
                        _SwitchRow(
                          title: 'Join mic muted',
                          subtitle:
                              'Always enter seats/rooms muted until you unmute.',
                          icon: Icons.mic_off_rounded,
                          value: state.autoJoinMicMuted,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(autoJoinMicMuted: value),
                          ),
                        ),
                        _SwitchRow(
                          title: 'Show entrance effects',
                          subtitle:
                              'Display your equipped entrance effects when joining rooms.',
                          icon: Icons.auto_awesome_rounded,
                          value: state.showEntranceEffects,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(showEntranceEffects: value),
                          ),
                        ),
                        _SwitchRow(
                          title: 'Image messages',
                          subtitle:
                              'Show image message controls in supported rooms.',
                          icon: Icons.image_rounded,
                          value: state.imageMessagesEnabled,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(imageMessagesEnabled: value),
                          ),
                        ),
                        _SwitchRow(
                          title: 'High quality animations',
                          subtitle:
                              'Use premium gift/room animations when available.',
                          icon: Icons.blur_on_rounded,
                          value: state.highQualityAnimations,
                          enabled: !state.dataSaverMode,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(highQualityAnimations: value),
                          ),
                        ),
                        _SwitchRow(
                          title: 'Data saver mode',
                          subtitle:
                              'Reduce animation/media usage for better performance.',
                          icon: Icons.speed_rounded,
                          value: state.dataSaverMode,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(
                              dataSaverMode: value,
                              highQualityAnimations: value
                                  ? false
                                  : s.highQualityAnimations,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SettingsSection(
                      title: 'Security',
                      subtitle:
                          'Inbox lock, biometrics, session security and sensitive previews.',
                      children: [
                        _SwitchRow(
                          title: 'Inbox lock',
                          subtitle:
                              'Require app PIN/lock before opening Inbox.',
                          icon: Icons.markunread_mailbox_rounded,
                          value: state.inboxLockEnabled,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(
                              inboxLockEnabled: value,
                              biometricUnlockEnabled: value
                                  ? s.biometricUnlockEnabled
                                  : false,
                            ),
                          ),
                        ),
                        _SwitchRow(
                          title: 'Biometric unlock',
                          subtitle:
                              'Use device biometrics for Inbox lock when available.',
                          icon: Icons.fingerprint_rounded,
                          value: state.biometricUnlockEnabled,
                          enabled: state.inboxLockEnabled,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(biometricUnlockEnabled: value),
                          ),
                        ),
                        _SwitchRow(
                          title: 'Auto-lock Inbox',
                          subtitle:
                              'Lock Inbox again when app goes background.',
                          icon: Icons.lock_clock_rounded,
                          value: state.autoLockInbox,
                          enabled: state.inboxLockEnabled,
                          onChanged: (value) =>
                              _update((s) => s.copyWith(autoLockInbox: value)),
                        ),
                        _SwitchRow(
                          title: 'Login alerts',
                          subtitle: 'Notify on new login/device access.',
                          icon: Icons.security_rounded,
                          value: state.loginAlertsEnabled,
                          onChanged: (value) => _update(
                            (s) => s.copyWith(loginAlertsEnabled: value),
                          ),
                        ),
                        _SwitchRow(
                          title: 'Hide sensitive previews',
                          subtitle: 'Hide message content in notifications.',
                          icon: Icons.privacy_tip_rounded,
                          value: state.hideSensitiveNotifications,
                          onChanged: (value) => _update(
                            (s) =>
                                s.copyWith(hideSensitiveNotifications: value),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const List<String> _builtInRingtones = [
  'Vibe Classic Ring',
  'Royal Room Ring',
  'Soft Bell Ring',
  'Crystal Call Ring',
];

const List<String> _builtInNotificationTones = [
  'Soft Vibe Ping',
  'Tiny Pop',
  'Gift Spark',
  'Room Invite Chime',
];
