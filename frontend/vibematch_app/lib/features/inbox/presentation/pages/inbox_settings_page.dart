import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/inbox_preferences_api_service.dart';
import '../../models/inbox_models.dart';
import '../widgets/inbox_lock_flow_sheets.dart';

class InboxSettingsPage extends StatefulWidget {
  const InboxSettingsPage({
    super.key,
    required this.lockStatus,
    required this.backupStatus,
    required this.strangersCanMessage,
    required this.strangersCanMentionInVibes,
    required this.onStartLockSetup,
    required this.onVerifyLockSetup,
    required this.onChangeLock,
    required this.onStartLockRecovery,
    required this.onVerifyLockRecovery,
    required this.onRequestCsLockRecovery,
    required this.onStartGoogleDriveSetup,
    required this.onConnectGoogleDrive,
    required this.onBackupEnabledChanged,
    required this.onFrequencyChanged,
    required this.onStrangersCanMessageChanged,
    required this.onStrangersCanMentionInVibesChanged,
    required this.onBackupNow,
    required this.onRestoreTap,
    required this.onBackTap,
  });

  final InboxLockStatus lockStatus;
  final InboxBackupStatus backupStatus;
  final bool strangersCanMessage;
  final bool strangersCanMentionInVibes;
  final Future<String?> Function(String mobileNumber) onStartLockSetup;
  final Future<void> Function(String mobileNumber, String otp, String lockCode) onVerifyLockSetup;
  final Future<void> Function(String currentLock, String newLock) onChangeLock;
  final Future<String?> Function(String mobileNumber) onStartLockRecovery;
  final Future<void> Function(String mobileNumber, String otp, String newLock) onVerifyLockRecovery;
  final Future<String> Function() onRequestCsLockRecovery;
  final Future<String> Function() onStartGoogleDriveSetup;
  final Future<void> Function(String? email, String? setupCode) onConnectGoogleDrive;
  final Future<void> Function(bool) onBackupEnabledChanged;
  final Future<void> Function(ChatBackupFrequency) onFrequencyChanged;
  final ValueChanged<bool> onStrangersCanMessageChanged;
  final ValueChanged<bool> onStrangersCanMentionInVibesChanged;
  final Future<void> Function() onBackupNow;
  final Future<void> Function() onRestoreTap;
  final VoidCallback onBackTap;

  @override
  State<InboxSettingsPage> createState() => _InboxSettingsPageState();
}

class _InboxSettingsPageState extends State<InboxSettingsPage> {
  static const _bg = Color(0xFFFAFAFA);
  static const _surface = Colors.white;
  static const _ink = Color(0xFF111114);
  static const _muted = Color(0xFF71717A);
  static const _line = Color(0xFFEDEDEF);
  static const _blue = Color(0xFF3797F0);

  final InboxPreferencesApiService _preferencesApi = const InboxPreferencesApiService();
  late bool _strangersCanMessage;
  late bool _strangersCanMentionInVibes;
  bool _backupBusy = false;
  bool _preferencesBusy = false;
  InboxPreferenceSettings? _preferences;

  @override
  void initState() {
    super.initState();
    _strangersCanMessage = widget.strangersCanMessage;
    _strangersCanMentionInVibes = widget.strangersCanMentionInVibes;
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final preferences = await _preferencesApi.loadPreferences();
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _strangersCanMessage = preferences.strangersCanMessage;
        _strangersCanMentionInVibes = preferences.strangersCanMentionInVibes;
      });
    } catch (_) {}
  }

  InboxPreferenceSettings get _effectivePreferences =>
      _preferences ??
      InboxPreferenceSettings(
        strangersCanMessage: _strangersCanMessage,
        strangersCanMentionInVibes: _strangersCanMentionInVibes,
        readReceiptsEnabled: true,
        onlineVisibility: 'everyone',
        lastSeenVisibility: 'everyone',
        typingActivityVisibility: 'everyone',
        storyVisibility: 'friends',
        deviceUnlockEnabled: false,
        defaultChatTheme: 'pearl',
        defaultWallpaperKey: 'premium_pearl',
      );

  Future<void> _savePreferences(InboxPreferenceSettings next, {String? feedback}) async {
    final previous = _preferences;
    setState(() {
      _preferencesBusy = true;
      _preferences = next;
      _strangersCanMessage = next.strangersCanMessage;
      _strangersCanMentionInVibes = next.strangersCanMentionInVibes;
    });
    try {
      final saved = await _preferencesApi.updatePreferences(next);
      if (!mounted) return;
      setState(() {
        _preferences = saved;
        _strangersCanMessage = saved.strangersCanMessage;
        _strangersCanMentionInVibes = saved.strangersCanMentionInVibes;
      });
      if (feedback != null) _showFeedback(feedback);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preferences = previous;
        if (previous != null) {
          _strangersCanMessage = previous.strangersCanMessage;
          _strangersCanMentionInVibes = previous.strangersCanMentionInVibes;
        }
      });
      _showFeedback('Could not save setting.');
    } finally {
      if (mounted) setState(() => _preferencesBusy = false);
    }
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _ink,
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
  }

  void _openLockSetup() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => InboxLockSetupSheet(
        onStartOtp: widget.onStartLockSetup,
        onVerifySetup: widget.onVerifyLockSetup,
      ),
    );
  }

  void _openChangeLock() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => InboxLockChangeSheet(onChangeLock: widget.onChangeLock),
    );
  }

  void _openRecovery() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => InboxLockRecoverySheet(
        registeredMobile: widget.lockStatus.mobileNumber,
        onStartRecovery: widget.onStartLockRecovery,
        onVerifyRecovery: widget.onVerifyLockRecovery,
        onRequestCs: widget.onRequestCsLockRecovery,
      ),
    );
  }

  void _openGoogleDriveSetup() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GoogleDriveSheet(
        backupStatus: widget.backupStatus,
        onStart: widget.onStartGoogleDriveSetup,
        onConnect: widget.onConnectGoogleDrive,
      ),
    );
  }

  Future<void> _setBackupEnabled(bool value) async {
    if (value && !widget.backupStatus.isAuthorized) {
      _openGoogleDriveSetup();
      return;
    }
    setState(() => _backupBusy = true);
    try {
      await widget.onBackupEnabledChanged(value);
      _showFeedback(value ? 'Chat backup enabled.' : 'Chat backup disabled.');
    } catch (_) {
      _showFeedback('Could not update backup.');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _setFrequency(ChatBackupFrequency frequency) async {
    setState(() => _backupBusy = true);
    try {
      await widget.onFrequencyChanged(frequency);
      _showFeedback('Backup set to ${frequency.label}.');
    } catch (_) {
      _showFeedback('Could not update frequency.');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _backupNow() async {
    if (!widget.backupStatus.isAuthorized) {
      _openGoogleDriveSetup();
      return;
    }
    setState(() => _backupBusy = true);
    try {
      await widget.onBackupNow();
      _showFeedback('Backup completed.');
    } catch (_) {
      _showFeedback('Backup failed.');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _restore() async {
    if (!widget.backupStatus.isAuthorized) {
      _openGoogleDriveSetup();
      return;
    }
    setState(() => _backupBusy = true);
    try {
      await widget.onRestoreTap();
      _showFeedback('Restore completed.');
    } catch (_) {
      _showFeedback('No backup found.');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  void _setStrangersCanMessage(bool value) {
    widget.onStrangersCanMessageChanged(value);
    _savePreferences(
      _effectivePreferences.copyWith(strangersCanMessage: value),
      feedback: value ? 'Message requests enabled.' : 'Message requests disabled.',
    );
  }

  void _setStrangersCanMentionInVibes(bool value) {
    widget.onStrangersCanMentionInVibesChanged(value);
    _savePreferences(
      _effectivePreferences.copyWith(strangersCanMentionInVibes: value),
      feedback: value ? 'Story mentions enabled.' : 'Story mentions limited.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final lockStatus = widget.lockStatus;
    final backup = widget.backupStatus;
    final prefs = _effectivePreferences;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _Header(onBackTap: widget.onBackTap),
            const SizedBox(height: 12),
            _Section(
              title: 'Security',
              children: [
                _SettingRow(
                  icon: lockStatus.isEnabled ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                  title: lockStatus.isEnabled ? 'Change lock' : 'Set up lock',
                  subtitle: lockStatus.isEnabled ? 'Update your private Inbox lock.' : 'Protect private conversations.',
                  onTap: lockStatus.isEnabled ? _openChangeLock : _openLockSetup,
                ),
                _SettingRow(
                  icon: Icons.support_agent_outlined,
                  title: 'Recover lock',
                  subtitle: lockStatus.recoveryRequested ? 'Recovery request sent.' : 'Use mobile OTP or support recovery.',
                  onTap: _openRecovery,
                ),
                _SwitchRow(
                  icon: Icons.fingerprint_rounded,
                  title: 'Device unlock',
                  subtitle: 'Use this device to unlock faster.',
                  value: prefs.deviceUnlockEnabled,
                  enabled: !_preferencesBusy,
                  onChanged: (value) => _savePreferences(
                    prefs.copyWith(deviceUnlockEnabled: value),
                    feedback: value ? 'Device unlock enabled.' : 'Device unlock disabled.',
                  ),
                ),
              ],
            ),
            _Section(
              title: 'Privacy',
              children: [
                _SwitchRow(
                  icon: Icons.mark_chat_unread_outlined,
                  title: 'Message requests',
                  subtitle: _strangersCanMessage ? 'Allow new requests.' : 'Block new requests.',
                  value: _strangersCanMessage,
                  enabled: !_preferencesBusy,
                  onChanged: _setStrangersCanMessage,
                ),
                _SwitchRow(
                  icon: Icons.alternate_email_rounded,
                  title: 'Story mentions',
                  subtitle: _strangersCanMentionInVibes ? 'Allow mentions from new people.' : 'Limit mentions to friends.',
                  value: _strangersCanMentionInVibes,
                  enabled: !_preferencesBusy,
                  onChanged: _setStrangersCanMentionInVibes,
                ),
                _SwitchRow(
                  icon: Icons.done_all_rounded,
                  title: 'Read receipts',
                  subtitle: 'Show when messages are read.',
                  value: prefs.readReceiptsEnabled,
                  enabled: !_preferencesBusy,
                  onChanged: (value) => _savePreferences(
                    prefs.copyWith(readReceiptsEnabled: value),
                    feedback: value ? 'Read receipts enabled.' : 'Read receipts disabled.',
                  ),
                ),
                _ChoiceRow(
                  title: 'Online status',
                  value: prefs.onlineVisibility,
                  onChanged: (value) => _savePreferences(prefs.copyWith(onlineVisibility: value)),
                ),
                _ChoiceRow(
                  title: 'Last seen',
                  value: prefs.lastSeenVisibility,
                  onChanged: (value) => _savePreferences(prefs.copyWith(lastSeenVisibility: value)),
                ),
                _ChoiceRow(
                  title: 'Typing',
                  value: prefs.typingActivityVisibility,
                  onChanged: (value) => _savePreferences(prefs.copyWith(typingActivityVisibility: value)),
                ),
                _ChoiceRow(
                  title: 'Story privacy',
                  value: prefs.storyVisibility,
                  onChanged: (value) => _savePreferences(prefs.copyWith(storyVisibility: value)),
                ),
              ],
            ),
            _Section(
              title: 'Backup',
              children: [
                _SettingRow(
                  icon: Icons.add_to_drive_outlined,
                  title: 'Chat backup',
                  subtitle: backup.isConnected ? backup.googleDriveEmail ?? 'Google Drive connected' : 'Google Drive not connected',
                  trailingText: backup.isEnabled ? 'On' : 'Off',
                  onTap: _openGoogleDriveSetup,
                ),
                _SwitchRow(
                  icon: Icons.cloud_sync_outlined,
                  title: 'Auto backup',
                  subtitle: backup.isConnected ? backup.frequency.label : 'Connect Drive first.',
                  value: backup.isEnabled,
                  enabled: !_backupBusy,
                  onChanged: _setBackupEnabled,
                ),
                _FrequencyRow(
                  value: backup.frequency,
                  enabled: backup.isEnabled && !_backupBusy,
                  onChanged: _setFrequency,
                ),
                _SettingRow(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Back up now',
                  subtitle: backup.lastBackupAt == null ? 'Last backup: Never' : 'Last backup: ${backup.lastBackupAt}',
                  onTap: _backupBusy ? null : _backupNow,
                ),
                _SettingRow(
                  icon: Icons.restore_rounded,
                  title: 'Restore backup',
                  subtitle: backup.lastRestoreAt == null ? 'Restore latest backup.' : 'Last restore: ${backup.lastRestoreAt}',
                  onTap: _backupBusy ? null : _restore,
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'FunKey keeps privacy controls short and clear. Advanced recovery and backup details stay inside their action screens.',
              style: TextStyle(color: _muted, fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBackTap});
  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onBackTap,
          icon: const Icon(Icons.arrow_back_rounded, color: _InboxSettingsPageState._ink, size: 22),
        ),
        const SizedBox(width: 4),
        const Expanded(
          child: Text(
            'Inbox Settings',
            style: TextStyle(color: _InboxSettingsPageState._ink, fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
            child: Text(
              title,
              style: const TextStyle(color: _InboxSettingsPageState._muted, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: _InboxSettingsPageState._surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _InboxSettingsPageState._line),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1) const Divider(height: 1, color: _InboxSettingsPageState._line, indent: 56),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.title, required this.subtitle, this.trailingText, this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Row(
              children: [
                Icon(icon, color: _InboxSettingsPageState._ink, size: 20),
                const SizedBox(width: 13),
                Expanded(child: _RowText(title: title, subtitle: subtitle)),
                if (trailingText != null)
                  Text(trailingText!, style: const TextStyle(color: _InboxSettingsPageState._muted, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: _InboxSettingsPageState._muted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.icon, required this.title, required this.subtitle, required this.value, required this.enabled, required this.onChanged});

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: _InboxSettingsPageState._ink, size: 20),
            const SizedBox(width: 13),
            Expanded(child: _RowText(title: title, subtitle: subtitle)),
            Switch.adaptive(
              value: value,
              activeThumbColor: _InboxSettingsPageState._blue,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _RowText extends StatelessWidget {
  const _RowText({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _InboxSettingsPageState._ink, fontSize: 14.3, fontWeight: FontWeight.w700)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _InboxSettingsPageState._muted, fontSize: 11.8, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.title, required this.value, required this.onChanged});

  final String title;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(color: _InboxSettingsPageState._ink, fontSize: 14.2, fontWeight: FontWeight.w700))),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                borderRadius: BorderRadius.circular(16),
                items: const [
                  DropdownMenuItem(value: 'everyone', child: Text('Everyone')),
                  DropdownMenuItem(value: 'friends', child: Text('Friends')),
                  DropdownMenuItem(value: 'nobody', child: Text('Nobody')),
                ],
                onChanged: (next) {
                  if (next != null) onChanged(next);
                },
                style: const TextStyle(color: _InboxSettingsPageState._muted, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrequencyRow extends StatelessWidget {
  const _FrequencyRow({required this.value, required this.enabled, required this.onChanged});

  final ChatBackupFrequency value;
  final bool enabled;
  final ValueChanged<ChatBackupFrequency> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 8, 13, 8),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, color: _InboxSettingsPageState._ink, size: 20),
            const SizedBox(width: 13),
            const Expanded(child: _RowText(title: 'Frequency', subtitle: 'Choose backup rhythm.')),
            DropdownButtonHideUnderline(
              child: DropdownButton<ChatBackupFrequency>(
                value: value,
                borderRadius: BorderRadius.circular(16),
                items: ChatBackupFrequency.values.map((item) => DropdownMenuItem(value: item, child: Text(item.label))).toList(),
                onChanged: enabled
                    ? (next) {
                        if (next != null) onChanged(next);
                      }
                    : null,
                style: const TextStyle(color: _InboxSettingsPageState._muted, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleDriveSheet extends StatefulWidget {
  const _GoogleDriveSheet({required this.backupStatus, required this.onStart, required this.onConnect});

  final InboxBackupStatus backupStatus;
  final Future<String> Function() onStart;
  final Future<void> Function(String? email, String? setupCode) onConnect;

  @override
  State<_GoogleDriveSheet> createState() => _GoogleDriveSheetState();
}

class _GoogleDriveSheetState extends State<_GoogleDriveSheet> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _code = TextEditingController();
  bool _busy = false;
  bool _manualCode = false;

  @override
  void initState() {
    super.initState();
    _email.text = widget.backupStatus.googleDriveEmail ?? '';
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: _InboxSettingsPageState._ink, content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700))));
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    try {
      final url = await widget.onStart();
      if (url.contains('dev_mock_drive_code')) {
        await widget.onConnect(_email.text.trim().isEmpty ? null : _email.text.trim(), 'dev_mock_drive_code');
        if (mounted) Navigator.pop(context);
        _toast('Google Drive connected.');
        return;
      }
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        setState(() => _manualCode = true);
        _toast('Complete Google sign-in, then enter the code here.');
      } else {
        setState(() => _manualCode = true);
        _toast('Enter the Google authorization code to finish.');
      }
    } catch (_) {
      _toast('Could not start Google Drive connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishWithCode() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      _toast('Enter the authorization code.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onConnect(_email.text.trim().isEmpty ? null : _email.text.trim(), code);
      if (mounted) Navigator.pop(context);
      _toast('Google Drive connected.');
    } catch (_) {
      _toast('Could not connect Google Drive.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.backupStatus.isConnected;
    return DraggableScrollableSheet(
      initialChildSize: _manualCode ? 0.72 : 0.54,
      minChildSize: 0.42,
      maxChildSize: 0.86,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + MediaQuery.paddingOf(context).bottom),
            children: [
              Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0xFFD4D4D8), borderRadius: BorderRadius.circular(99)))),
              const SizedBox(height: 18),
              const Icon(Icons.add_to_drive_rounded, color: _InboxSettingsPageState._blue, size: 36),
              const SizedBox(height: 10),
              Text(
                connected ? 'Google Drive connected' : 'Chat backup',
                style: const TextStyle(color: _InboxSettingsPageState._ink, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                connected ? widget.backupStatus.googleDriveEmail ?? 'Connected' : 'Save your chats to Google Drive.',
                style: const TextStyle(color: _InboxSettingsPageState._muted, fontSize: 13, height: 1.35, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: _fieldDecoration('Google account email'),
              ),
              if (_manualCode) ...[
                const SizedBox(height: 10),
                TextField(controller: _code, decoration: _fieldDecoration('Authorization code')),
              ],
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _InboxSettingsPageState._blue,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _busy ? null : (_manualCode ? _finishWithCode : _connect),
                child: Text(_manualCode ? 'Finish connection' : connected ? 'Reconnect Google Drive' : 'Connect Google Drive'),
              ),
              TextButton(
                onPressed: _busy ? null : () => setState(() => _manualCode = !_manualCode),
                child: Text(_manualCode ? 'Hide manual code' : 'Enter code manually'),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF7F7F8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _InboxSettingsPageState._blue)),
    );
  }
}
