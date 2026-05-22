import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
      setState(() => _loadError = error.toString());
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
        _toast(error.toString());
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
      if (mounted) _toast(error.toString());
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
                child: _SettingsErrorState(
                  message: _loadError!,
                  onRetry: _loadSettings,
                ),
              )
            else if (state == null)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF251538)),
                ),
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

class _SettingsErrorState extends StatelessWidget {
  const _SettingsErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFF7B6A86),
              size: 36,
            ),
            const SizedBox(height: 10),
            const Text(
              'Settings unavailable',
              style: TextStyle(
                color: Color(0xFF251538),
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF7B6A86),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.saving,
    required this.onBack,
    required this.onReset,
  });

  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF251538),
              size: 28,
            ),
          ),
          const Expanded(
            child: Text(
              'Settings',
              style: TextStyle(
                color: Color(0xFF251538),
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
          ),
          if (saving)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Color(0xFF251538),
              ),
            ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onReset,
            child: const Text(
              'Reset',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsHeroCard extends StatelessWidget {
  const _SettingsHeroCard({
    required this.notificationsEnabled,
    required this.anonymousEnabled,
    required this.ringtoneName,
    required this.notificationToneName,
  });

  final bool notificationsEnabled;
  final bool anonymousEnabled;
  final String ringtoneName;
  final String notificationToneName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _settingsPanelDecoration(radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF6D5DF6), Color(0xFFE84C72)],
                  ),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Account Controls',
                  style: TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                label: notificationsEnabled
                    ? 'Notifications On'
                    : 'Notifications Off',
                active: notificationsEnabled,
              ),
              _StatusPill(
                label: anonymousEnabled ? 'Anonymous On' : 'Anonymous Off',
                active: anonymousEnabled,
              ),
              _StatusPill(label: ringtoneName, active: true),
              _StatusPill(label: notificationToneName, active: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _settingsPanelDecoration(radius: 28),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF251538),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF7B6A86),
              fontSize: 11.5,
              height: 1.28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.premium = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final bool enabled;
  final bool premium;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = enabled;
    return Opacity(
      opacity: active ? 1 : 0.48,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF6D5DF6).withValues(alpha: 0.11),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF6D5DF6), size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF251538),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (premium) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3D3),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'SVIP',
                            style: TextStyle(
                              color: Color(0xFFC99A3B),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF7B6A86),
                      fontSize: 11,
                      height: 1.22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeThumbColor: const Color(0xFF12C7B7),
              activeTrackColor: const Color(0xFF12C7B7).withValues(alpha: 0.35),
              onChanged: active ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFE84C72).withValues(alpha: 0.11),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFFE84C72), size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF7B6A86),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF7B6A86),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _TonePickerSheet extends StatelessWidget {
  const _TonePickerSheet({
    required this.title,
    required this.selectedName,
    required this.builtInTones,
    required this.onBuiltInSelected,
    required this.onPickFile,
  });

  final String title;
  final String selectedName;
  final List<String> builtInTones;
  final ValueChanged<String> onBuiltInSelected;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFECE2D8)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF251538),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            for (final tone in builtInTones)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ToneOption(
                  title: tone,
                  selected: tone == selectedName,
                  onTap: () => onBuiltInSelected(tone),
                ),
              ),
            const SizedBox(height: 4),
            _ActionRow(
              title: 'Choose from device',
              subtitle: 'MP3, M4A, AAC, WAV or OGG',
              icon: Icons.audio_file_rounded,
              onTap: onPickFile,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToneOption extends StatelessWidget {
  const _ToneOption({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF12C7B7).withValues(alpha: 0.12)
              : const Color(0xFFFAF7F1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF12C7B7) : const Color(0xFFECE2D8),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected
                  ? const Color(0xFF12C7B7)
                  : const Color(0xFF7B6A86),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF251538),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF12C7B7).withValues(alpha: 0.12)
            : const Color(0xFFECE2D8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? const Color(0xFF064D46) : const Color(0xFF7B6A86),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ConfirmResetSheet extends StatelessWidget {
  const _ConfirmResetSheet({required this.onCancel, required this.onReset});

  final VoidCallback onCancel;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reset settings?',
              style: TextStyle(
                color: Color(0xFF251538),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This restores all account settings to default on this device.',
              style: TextStyle(
                color: Color(0xFF7B6A86),
                fontSize: 12.5,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onReset,
                    child: const Text('Reset'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _settingsPanelDecoration({required double radius}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFECE2D8)),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF251538).withValues(alpha: 0.04),
        blurRadius: 18,
        offset: const Offset(0, 9),
      ),
    ],
  );
}
