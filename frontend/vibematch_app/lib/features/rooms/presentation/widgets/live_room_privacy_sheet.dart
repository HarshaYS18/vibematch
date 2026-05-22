import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/security/screenshot_guard_service.dart';
import '../../../../core/ui/vm_motion.dart';
import '../../data/active_room_context.dart';
import '../../data/live_room_settings_event_bus.dart';
import '../../data/room_api_service.dart';
import '../../data/room_settings_repository.dart';
import '../live_room_models.dart';
import 'room_theme.dart';

class LiveRoomPrivacySheet extends StatefulWidget {
  const LiveRoomPrivacySheet({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    this.roomId,
  });

  final RoomPrivacyMode currentMode;
  final ValueChanged<RoomPrivacyMode> onModeChanged;
  final String? roomId;

  @override
  State<LiveRoomPrivacySheet> createState() => _LiveRoomPrivacySheetState();
}

class _LiveRoomPrivacySheetState extends State<LiveRoomPrivacySheet> {
  late RoomPrivacyMode _mode;
  final TextEditingController _passwordController = TextEditingController();
  final RoomApiService _roomApi = const RoomApiService();
  final RoomSettingsRepository _settingsRepository = RoomSettingsRepository();
  bool _saving = false;
  bool _loadingSettings = false;
  bool _allowScreenshots = true;
  String _selectedLanguage = 'Telugu';

  static const List<String> _languages = <String>[
    'Telugu',
    'Hindi',
    'English',
    'Tamil',
    'Malayalam',
    'Kannada',
    'Bengali',
    'Marathi',
    'Punjabi',
    'Gujarati',
    'Odia',
    'Urdu',
    'Arabic',
    'Spanish',
    'French',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _mode = widget.currentMode;
    unawaited(_loadSettings());
  }

  @override
  void dispose() {
    _settingsRepository.close();
    _passwordController.dispose();
    super.dispose();
  }

  String get _roomId =>
      (widget.roomId ?? ActiveRoomContext.roomPublicId ?? '').trim();

  Future<void> _loadSettings() async {
    final roomId = _roomId;
    if (roomId.isEmpty) return;
    setState(() => _loadingSettings = true);
    try {
      final settings = await _settingsRepository.fetchRoomSettings(roomId);
      await ScreenshotGuardService.applyRoomScreenshotPolicy(
        allowScreenshots: settings.allowScreenshots,
      );
      if (!mounted) return;
      setState(() {
        _selectedLanguage = settings.language?.trim().isNotEmpty == true
            ? settings.language!.trim()
            : _selectedLanguage;
        _allowScreenshots = settings.allowScreenshots;
        _mode = settings.mode?.trim().isNotEmpty == true
            ? privacyModeFromTitle(settings.mode!)
            : _mode;
      });
      _publishSettingsEvent(
        modeTitle: settings.mode,
        language: settings.language,
        allowScreenshots: settings.allowScreenshots,
      );
    } catch (_) {
      // Settings sheet can still operate from current room state.
    } finally {
      if (mounted) setState(() => _loadingSettings = false);
    }
  }

  Future<void> _saveAccessSettings({
    String? language,
    RoomPrivacyMode? mode,
    bool? allowScreenshots,
  }) async {
    if (_saving) return;
    final roomId = _roomId;
    if (roomId.isEmpty) {
      RoomToast.show(context, 'Room ID missing. Re-enter room and try again.');
      return;
    }

    final nextMode = mode ?? _mode;
    final lockText = _passwordController.text.trim();
    if (mode == RoomPrivacyMode.locked && lockText.isEmpty) {
      setState(() => _mode = nextMode);
      RoomToast.show(context, 'Enter a room lock before locking the room.');
      return;
    }

    setState(() {
      _saving = true;
      if (language != null) _selectedLanguage = language;
      if (allowScreenshots != null) _allowScreenshots = allowScreenshots;
      if (mode != null) _mode = mode;
    });

    try {
      final settings = await _settingsRepository.updateAccessSettings(
        roomPublicId: roomId,
        language: language,
        mode: mode == null ? null : _backendModeName(mode),
        lockPassword: mode == RoomPrivacyMode.locked ? lockText : null,
        allowScreenshots: allowScreenshots,
      );
      await ScreenshotGuardService.applyRoomScreenshotPolicy(
        allowScreenshots: settings.allowScreenshots,
      );
      if (!mounted) return;
      final confirmedMode = settings.mode?.trim().isNotEmpty == true
          ? privacyModeFromTitle(settings.mode!)
          : _mode;
      setState(() {
        _selectedLanguage = settings.language?.trim().isNotEmpty == true
            ? settings.language!.trim()
            : _selectedLanguage;
        _allowScreenshots = settings.allowScreenshots;
        _mode = confirmedMode;
      });
      _publishSettingsEvent(
        modeTitle: settings.mode,
        language: settings.language,
        allowScreenshots: settings.allowScreenshots,
      );
      if (mode != null) widget.onModeChanged(confirmedMode);
      RoomToast.show(
        context,
        _successMessage(
          language: language,
          mode: mode,
          allowScreenshots: allowScreenshots,
          confirmedMode: confirmedMode,
        ),
      );
      if (mode != null) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _mode = widget.currentMode);
      RoomToast.show(context, error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _publishSettingsEvent({
    String? modeTitle,
    String? language,
    bool? allowScreenshots,
  }) {
    final roomId = _roomId;
    if (roomId.isEmpty) return;

    LiveRoomSettingsEventBus.publish(
      LiveRoomSettingsEvent(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        roomId: roomId,
        privacyModeTitle: modeTitle ?? _backendModeName(_mode),
        allowScreenshots: allowScreenshots ?? _allowScreenshots,
        language: language ?? _selectedLanguage,
      ),
    );
  }

  String _backendModeName(RoomPrivacyMode mode) {
    switch (mode) {
      case RoomPrivacyMode.open:
        return 'Open';
      case RoomPrivacyMode.locked:
        return 'Locked';
      case RoomPrivacyMode.membersOnly:
        return 'Members Only';
      case RoomPrivacyMode.privateVibe:
        return 'Secret Vibe';
    }
  }

  String _successMessage({
    String? language,
    RoomPrivacyMode? mode,
    bool? allowScreenshots,
    required RoomPrivacyMode confirmedMode,
  }) {
    if (language != null) return 'Room language updated to $language.';
    if (allowScreenshots != null)
      return allowScreenshots
          ? 'Screenshots are now allowed.'
          : 'Screenshots are now disabled.';
    switch (confirmedMode) {
      case RoomPrivacyMode.open:
        return 'Room is now Open and visible in eligible lists.';
      case RoomPrivacyMode.locked:
        return 'Room is now Locked. Host/admins and invited/approved users can enter; visitors must type the lock.';
      case RoomPrivacyMode.membersOnly:
        return 'Room is now Members Only. Only approved chatroom members, room admins, host, and Owner roles can enter.';
      case RoomPrivacyMode.privateVibe:
        return 'Secret Vibe enabled. Room is hidden from public discovery.';
    }
  }

  String _modeDescription(RoomPrivacyMode mode) {
    switch (mode) {
      case RoomPrivacyMode.open:
        return 'Visible publicly. Visitors can enter, but they are not members until approved.';
      case RoomPrivacyMode.locked:
        return 'Host/admins and invited/approved users enter directly. Other users must type the room lock.';
      case RoomPrivacyMode.membersOnly:
        return 'Only approved chatroom members, room admins, host, and Owner roles can enter.';
      case RoomPrivacyMode.privateVibe:
        return 'Hidden from discovery/trending. No public presence reveal. Entry only by host/admin invite or approval.';
    }
  }

  void _openLanguageSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: VmMotion.sheetAnimationStyle,
      builder: (context) => VmFadeSlide(
        child: Container(
          margin: const EdgeInsets.all(14),
          padding: EdgeInsets.fromLTRB(
            14,
            12,
            14,
            MediaQuery.paddingOf(context).bottom + 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(width: 42),
              const SizedBox(height: 12),
              const Text(
                'Room Language',
                style: TextStyle(
                  color: RoomColors.plum,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _languages.length,
                  itemBuilder: (context, index) {
                    final language = _languages[index];
                    final selected = language == _selectedLanguage;
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.language_rounded,
                        color: selected ? RoomColors.aqua : RoomColors.plum,
                        size: 20,
                      ),
                      title: Text(
                        language,
                        style: TextStyle(
                          color: RoomColors.plum,
                          fontWeight: selected
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        unawaited(_saveAccessSettings(language: language));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.60,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            12,
            8,
            12,
            MediaQuery.paddingOf(context).bottom + 10,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(width: 42),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Room Privacy',
                      style: TextStyle(
                        color: RoomColors.plum,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (_saving || _loadingSettings)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Language, screenshots and mode changes are saved to backend for this lifetime room.',
                style: TextStyle(
                  color: Color(0xFF82758E),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    _SettingsTile(
                      icon: Icons.language_rounded,
                      title: 'Language',
                      subtitle: _selectedLanguage,
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF82758E),
                        size: 20,
                      ),
                      onTap: _saving ? null : _openLanguageSheet,
                    ),
                    _ScreenshotTile(
                      value: _allowScreenshots,
                      enabled: !_saving,
                      onChanged: (value) => unawaited(
                        _saveAccessSettings(allowScreenshots: value),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...RoomPrivacyMode.values.map((mode) {
                      return _PrivacyTile(
                        mode: mode,
                        selected: _mode == mode,
                        description: _modeDescription(mode),
                        saving: _saving,
                        onTap: () {
                          setState(() => _mode = mode);
                          if (mode != RoomPrivacyMode.locked)
                            unawaited(_saveAccessSettings(mode: mode));
                        },
                      );
                    }),
                    if (_mode == RoomPrivacyMode.locked) ...[
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        enabled: !_saving,
                        maxLength: 64,
                        decoration: InputDecoration(
                          hintText: 'Enter room lock',
                          counterText: '',
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFFAF7F1),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => unawaited(
                          _saveAccessSettings(mode: RoomPrivacyMode.locked),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => unawaited(
                                  _saveAccessSettings(
                                    mode: RoomPrivacyMode.locked,
                                  ),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RoomColors.plum,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.lock_rounded, size: 16),
                          label: const Text(
                            'Lock Room',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFAF6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8DDCF)),
        ),
        child: Row(
          children: [
            Icon(icon, color: RoomColors.plum, size: 18),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: RoomColors.plum,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF82758E),
                      fontSize: 10.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _ScreenshotTile extends StatelessWidget {
  const _ScreenshotTile({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8DDCF)),
      ),
      child: Row(
        children: [
          Icon(
            value
                ? Icons.screenshot_monitor_rounded
                : Icons.no_photography_rounded,
            color: value ? RoomColors.aqua : RoomColors.coral,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Screenshots',
                  style: TextStyle(
                    color: RoomColors.plum,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value ? 'Allowed in this room' : 'Disabled in this room',
                  style: const TextStyle(
                    color: Color(0xFF82758E),
                    fontSize: 10.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: RoomColors.aqua,
          ),
        ],
      ),
    );
  }
}

class _PrivacyTile extends StatelessWidget {
  const _PrivacyTile({
    required this.mode,
    required this.selected,
    required this.description,
    required this.saving,
    required this.onTap,
  });

  final RoomPrivacyMode mode;
  final bool selected;
  final String description;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: saving ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? RoomColors.aqua.withValues(alpha: 0.12)
              : const Color(0xFFFCFAF6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? RoomColors.aqua.withValues(alpha: 0.30)
                : const Color(0xFFE8DDCF),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                mode.icon,
                color: selected ? RoomColors.aqua : RoomColors.plum,
                size: 18,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: TextStyle(
                      color: selected ? RoomColors.aqua : RoomColors.plum,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF82758E),
                      fontSize: 10.3,
                      height: 1.18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: RoomColors.aqua,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
