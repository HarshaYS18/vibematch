import 'package:flutter/material.dart';

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
    } catch (_) {
      // Keep the existing values from the controller if backend preferences are unavailable.
    }
  }

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
      _showFeedback('Could not save Inbox privacy setting.');
    } finally {
      if (mounted) setState(() => _preferencesBusy = false);
    }
  }

  InboxPreferenceSettings get _effectivePreferences => _preferences ?? InboxPreferenceSettings(
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

  void _openLockSetup() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => InboxLockSetupSheet(onStartOtp: widget.onStartLockSetup, onVerifySetup: widget.onVerifyLockSetup),
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
      builder: (_) => _GoogleDriveSetupSheet(
        currentEmail: widget.backupStatus.googleDriveEmail,
        onStart: widget.onStartGoogleDriveSetup,
        onConnect: widget.onConnectGoogleDrive,
      ),
    );
  }

  Future<void> _setBackupEnabled(bool value) async {
    if (value && !widget.backupStatus.isAuthorized) {
      _showFeedback('Connect Google Drive first.');
      _openGoogleDriveSetup();
      return;
    }
    setState(() => _backupBusy = true);
    try {
      await widget.onBackupEnabledChanged(value);
      _showFeedback(value ? 'Chat backup enabled' : 'Chat backup disabled');
    } catch (_) {
      _showFeedback('Could not update backup setting.');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _setFrequency(ChatBackupFrequency frequency) async {
    setState(() => _backupBusy = true);
    try {
      await widget.onFrequencyChanged(frequency);
      _showFeedback('Backup frequency set to ${frequency.label}');
    } catch (_) {
      _showFeedback('Could not update backup frequency.');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _backupNow() async {
    if (!widget.backupStatus.isAuthorized) {
      _showFeedback('Connect Google Drive first.');
      _openGoogleDriveSetup();
      return;
    }
    setState(() => _backupBusy = true);
    try {
      await widget.onBackupNow();
      _showFeedback('Inbox backup completed.');
    } catch (_) {
      _showFeedback('Backup failed. Check Google Drive setup.');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _restore() async {
    if (!widget.backupStatus.isAuthorized) {
      _showFeedback('Connect Google Drive first.');
      _openGoogleDriveSetup();
      return;
    }
    setState(() => _backupBusy = true);
    try {
      await widget.onRestoreTap();
      _showFeedback('Inbox restore completed.');
    } catch (_) {
      _showFeedback('Restore failed. No backup found or Drive setup failed.');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  void _setStrangersCanMessage(bool value) {
    widget.onStrangersCanMessageChanged(value);
    _savePreferences(_effectivePreferences.copyWith(strangersCanMessage: value), feedback: value ? 'Strangers can message you' : 'Stranger messages disabled');
  }

  void _setStrangersCanMentionInVibes(bool value) {
    widget.onStrangersCanMentionInVibesChanged(value);
    _savePreferences(_effectivePreferences.copyWith(strangersCanMentionInVibes: value), feedback: value ? 'Strangers can mention you in Vibes' : 'Stranger Vibes mentions disabled');
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538), content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800))));
  }

  @override
  Widget build(BuildContext context) {
    final lockStatus = widget.lockStatus;
    final backup = widget.backupStatus;
    final prefs = _effectivePreferences;
    final backupSubtitle = backup.isConnected
        ? '${backup.googleDriveEmail} • ${backup.frequency.label}'
        : 'Authorize Google Drive to store encrypted chat backups.';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          children: [
            Row(
              children: [
                IconButton(onPressed: widget.onBackTap, icon: const Icon(Icons.arrow_back_rounded)),
                const SizedBox(width: 6),
                const Expanded(child: Text('Inbox Settings', style: TextStyle(color: Color(0xFF251538), fontSize: 24, fontWeight: FontWeight.w900))),
                const Icon(Icons.settings_rounded, color: Color(0xFF4A2A63)),
              ],
            ),
            const SizedBox(height: 10),
            _SettingsCard(
              child: Column(
                children: [
                  _ActionRow(
                    icon: lockStatus.isEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                    title: lockStatus.isEnabled ? 'Change Inbox lock' : 'Set up Inbox lock',
                    subtitle: lockStatus.isEnabled
                        ? 'Use your current lock to set a new one. Super Owner support codes work as fallback.'
                        : 'Create your first Inbox lock with recovery mobile OTP.',
                    onTap: lockStatus.isEnabled ? _openChangeLock : _openLockSetup,
                  ),
                  const Divider(color: Color(0xFFECE2D8)),
                  _ActionRow(
                    icon: Icons.support_agent_rounded,
                    title: 'Forgot Inbox lock?',
                    subtitle: lockStatus.recoveryRequested
                        ? 'Recovery request submitted. Contact Vibe Match Team / CS.'
                        : 'Recover with linked mobile OTP or request CS/Super Owner reset support.',
                    onTap: _openRecovery,
                  ),
                  const Divider(color: Color(0xFFECE2D8)),
                  SwitchListTile(
                    value: prefs.deviceUnlockEnabled,
                    onChanged: _preferencesBusy ? null : (value) => _savePreferences(prefs.copyWith(deviceUnlockEnabled: value), feedback: value ? 'Device unlock shortcut enabled' : 'Device unlock shortcut disabled'),
                    activeThumbColor: const Color(0xFF12C7B7),
                    title: const Text('Device unlock shortcut', style: TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900)),
                    subtitle: const Text('Uses phone fingerprint/Face ID locally after backend lock is configured. Fingerprint data is never sent to backend.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              child: Column(
                children: [
                  SwitchListTile(
                    value: _strangersCanMessage,
                    onChanged: _preferencesBusy ? null : _setStrangersCanMessage,
                    activeThumbColor: const Color(0xFF12C7B7),
                    title: const Text('Stranger messages', style: TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900)),
                    subtitle: Text(_strangersCanMessage ? 'Strangers can message you. These appear under Stranger messages.' : 'Strangers cannot start new chats with you.', style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                  const Divider(color: Color(0xFFECE2D8)),
                  SwitchListTile(
                    value: _strangersCanMentionInVibes,
                    onChanged: _preferencesBusy ? null : _setStrangersCanMentionInVibes,
                    activeThumbColor: const Color(0xFF12C7B7),
                    title: const Text('Stranger Vibes mentions', style: TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900)),
                    subtitle: Text(_strangersCanMentionInVibes ? 'Strangers can mention you in Vibes and Vibe comments.' : 'Only friends/following rules can mention you in Vibes.', style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                  const Divider(color: Color(0xFFECE2D8)),
                  SwitchListTile(
                    value: prefs.readReceiptsEnabled,
                    onChanged: _preferencesBusy ? null : (value) => _savePreferences(prefs.copyWith(readReceiptsEnabled: value), feedback: value ? 'Read receipts enabled' : 'Read receipts disabled'),
                    activeThumbColor: const Color(0xFF12C7B7),
                    title: const Text('Read receipts', style: TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900)),
                    subtitle: const Text('Control whether people can see blue read ticks in direct chats.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                  const Divider(color: Color(0xFFECE2D8)),
                  _VisibilityRow(label: 'Online status', value: prefs.onlineVisibility, onChanged: (value) => _savePreferences(prefs.copyWith(onlineVisibility: value), feedback: 'Online status privacy updated')),
                  const Divider(color: Color(0xFFECE2D8)),
                  _VisibilityRow(label: 'Last seen', value: prefs.lastSeenVisibility, onChanged: (value) => _savePreferences(prefs.copyWith(lastSeenVisibility: value), feedback: 'Last seen privacy updated')),
                  const Divider(color: Color(0xFFECE2D8)),
                  _VisibilityRow(label: 'Typing/activity', value: prefs.typingActivityVisibility, onChanged: (value) => _savePreferences(prefs.copyWith(typingActivityVisibility: value), feedback: 'Typing privacy updated')),
                  const Divider(color: Color(0xFFECE2D8)),
                  _VisibilityRow(label: 'Story privacy', value: prefs.storyVisibility, onChanged: (value) => _savePreferences(prefs.copyWith(storyVisibility: value), feedback: 'Story privacy updated')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              child: Column(
                children: [
                  _ActionRow(
                    icon: Icons.add_to_drive_rounded,
                    title: backup.isConnected ? 'Google Drive connected' : 'Connect Google Drive',
                    subtitle: backupSubtitle,
                    onTap: _openGoogleDriveSetup,
                  ),
                  const Divider(color: Color(0xFFECE2D8)),
                  SwitchListTile(
                    value: backup.isEnabled,
                    onChanged: _backupBusy ? null : _setBackupEnabled,
                    activeThumbColor: const Color(0xFF12C7B7),
                    title: const Text('Chat backup', style: TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900)),
                    subtitle: Text(backup.isEnabled ? 'Backup is on. ${backup.frequency.label} backup is selected.' : 'Backup is off. Connect Drive before enabling automatic backups.', style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                  const Divider(color: Color(0xFFECE2D8)),
                  const Align(alignment: Alignment.centerLeft, child: Text('Backup frequency', style: TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w900))),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ChatBackupFrequency.values.map((item) {
                      final selected = item == backup.frequency;
                      return InkWell(
                        onTap: backup.isEnabled && !_backupBusy ? () => _setFrequency(item) : null,
                        borderRadius: BorderRadius.circular(999),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 160),
                          opacity: backup.isEnabled ? 1 : 0.46,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(color: selected ? const Color(0xFF251538) : const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(999), border: Border.all(color: selected ? const Color(0xFF251538) : const Color(0xFFECE2D8))),
                            child: Text(item.label, style: TextStyle(color: selected ? Colors.white : const Color(0xFF4A2A63), fontSize: 11.5, fontWeight: FontWeight.w900)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              child: Column(
                children: [
                  _ActionRow(icon: Icons.cloud_upload_rounded, title: 'Back up now', subtitle: backup.lastBackupAt == null ? 'Create your first encrypted Drive backup.' : 'Last backup: ${backup.lastBackupAt}', onTap: _backupBusy ? () {} : _backupNow),
                  const Divider(color: Color(0xFFECE2D8)),
                  _ActionRow(icon: Icons.restore_rounded, title: 'Restore from backup', subtitle: backup.lastRestoreAt == null ? 'Restore latest available Drive backup.' : 'Last restore: ${backup.lastRestoreAt}', onTap: _backupBusy ? () {} : _restore),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const _SettingsCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.security_rounded, color: Color(0xFF4A2A63), size: 20),
                  SizedBox(width: 10),
                  Expanded(child: Text('Inbox lock, privacy settings, Secret Drift, backups, and locked-chat recovery are backend-backed. Device unlock is a local shortcut only and never sends fingerprint data to the backend.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12, height: 1.35, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityRow extends StatelessWidget {
  const _VisibilityRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF251538), fontSize: 13.5, fontWeight: FontWeight.w900))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFECE2D8))),
            child: DropdownButtonHideUnderline(
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
                style: const TextStyle(color: Color(0xFF4A2A63), fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleDriveSetupSheet extends StatefulWidget {
  const _GoogleDriveSetupSheet({required this.currentEmail, required this.onStart, required this.onConnect});

  final String? currentEmail;
  final Future<String> Function() onStart;
  final Future<void> Function(String? email, String? setupCode) onConnect;

  @override
  State<_GoogleDriveSetupSheet> createState() => _GoogleDriveSetupSheetState();
}

class _GoogleDriveSetupSheetState extends State<_GoogleDriveSetupSheet> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _authUrl;

  @override
  void initState() {
    super.initState();
    _email.text = widget.currentEmail ?? '';
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final url = await widget.onStart();
      if (url.contains('dev_mock_drive_code')) {
        _code.text = 'dev_mock_drive_code';
      }
      setState(() => _authUrl = url);
      _toast(url.contains('dev_mock_drive_code') ? 'Dev backup setup ready. Tap Connect to enable chat backup.' : 'Google Drive authorization started. Paste auth code after approval.');
    } catch (_) {
      _toast('Could not start Google Drive setup.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    try {
      final trimmedCode = _code.text.trim();
      await widget.onConnect(
        _email.text.trim().isEmpty ? null : _email.text.trim(),
        trimmedCode.isEmpty ? 'dev_mock_drive_code' : trimmedCode,
      );
      if (mounted) Navigator.pop(context);
      _toast('Google Drive connected for Inbox backup.');
    } catch (_) {
      _toast('Could not connect Google Drive.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538), content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800))));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 30, offset: const Offset(0, 14))]),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999)))),
              const SizedBox(height: 12),
              const Text('Google Drive Backup', style: TextStyle(color: Color(0xFF251538), fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              const Text('Authorize Google Drive so Vibe Match can store encrypted Inbox backups and restore them later.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12.2, height: 1.35, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration('Google account email', Icons.alternate_email_rounded),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _code,
                decoration: _inputDecoration('Authorization code', Icons.key_rounded),
              ),
              if (_authUrl != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFECE2D8))),
                  child: Text(_authUrl!, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF4A2A63), fontSize: 10.5, fontWeight: FontWeight.w800)),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _SheetButton(label: 'Start auth', icon: Icons.open_in_new_rounded, busy: _busy, onTap: _start, dark: false)),
                  const SizedBox(width: 10),
                  Expanded(child: _SheetButton(label: 'Connect', icon: Icons.add_to_drive_rounded, busy: _busy, onTap: _connect, dark: true)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF4A2A63), size: 20),
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w800),
      filled: true,
      fillColor: const Color(0xFFFAF7F1),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF12C7B7), width: 1.4)),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({required this.label, required this.icon, required this.busy, required this.onTap, required this.dark});
  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: busy ? null : onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(color: dark ? const Color(0xFF251538) : const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18), border: Border.all(color: dark ? const Color(0xFF251538) : const Color(0xFFECE2D8))),
        child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: dark ? Colors.white : const Color(0xFF4A2A63), size: 18), const SizedBox(width: 6), Text(label, style: TextStyle(color: dark ? Colors.white : const Color(0xFF251538), fontWeight: FontWeight.w900))])),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFECE2D8))), child: child);
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF8C5CF6).withValues(alpha: 0.11), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: const Color(0xFF8C5CF6), size: 21)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 13.5, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700))])),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF9B8CA5)),
        ]),
      ),
    );
  }
}
