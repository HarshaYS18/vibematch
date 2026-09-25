import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/security/screenshot_guard_service.dart';
import '../../../../room_session/data/room_session_repository.dart';
import '../../data/live_room_media_signaling_service.dart';
import '../../data/room_seat_layout_sync_service.dart';
import '../../data/room_settings_repository.dart';
import '../live_room_models.dart';
import '../modules/cricket_mode_module.dart';
import '../widgets/cricket_room_backgrounds.dart';
import '../widgets/room_theme.dart';
import '../widgets/vibesync_room_module.dart';

/// Presentation facade over the canonical [RoomSessionRepository].
///
/// Durable room settings are never owned here. The facade reads room
/// name/privacy/background/seat-layout/announcement/permission settings from
/// [RoomSessionRepository.currentState] and reconciles authoritative REST
/// responses back into that repository. Only route-local UI state is retained
/// locally (minimize/leave flow, unread badge, VibeSync overlay, bubble offset).
class LiveRoomStateController {
  LiveRoomStateController({
    required RoomSessionRepository roomSessionRepository,
    required VoidCallback onChanged,
    required String initialRoomName,
    required String initialRoomId,
    required String initialModeTitle,
    RoomBackgroundTheme? initialBackgroundTheme,
    LiveRoomStateSnapshot? initialStateSnapshot,
    bool preserveInitialBackgroundOnFirstLoad = false,
    int initialInboxUnreadCount = 4,
  }) : _roomSessionRepository = roomSessionRepository,
       _onChanged = onChanged,
       _initialRoomName =
           initialStateSnapshot?.roomName ?? initialRoomName,
       _initialRoomId = initialStateSnapshot?.roomId ?? initialRoomId,
       _initialModeTitle =
           initialStateSnapshot?.privacyMode.name ?? initialModeTitle,
       _initialRoomImagesEnabled =
           initialStateSnapshot?.roomImagesEnabled ?? true,
       _initialGuestMessagesEnabled =
           initialStateSnapshot?.guestMessagesEnabled ?? true,
       _initialApplyOnlyModeEnabled =
           initialStateSnapshot?.applyOnlyModeEnabled ?? false,
       _initialAllowScreenshots =
           initialStateSnapshot?.allowScreenshots ?? true,
       _initialBackgroundTheme =
           initialStateSnapshot?.selectedBackgroundTheme ??
           initialBackgroundTheme ??
           defaultRoomBackgroundTheme,
       _initialSeatLayoutId =
           initialStateSnapshot?.seatLayoutId ?? '5x2',
       _initialAnnouncementText =
           initialStateSnapshot?.announcementText ?? '',
       _inboxUnreadCount =
           initialStateSnapshot?.inboxUnreadCount ??
           initialInboxUnreadCount,
       _vibeSyncState =
           initialStateSnapshot?.vibeSyncState ??
           VibeSyncRoomState.inactive,
       _bubbleOffset =
           initialStateSnapshot?.bubbleOffset ?? const Offset(24, 120) {
    LiveRoomMediaSignalingService.instance.configureRoom(
      roomId: roomId,
      roomName: roomName,
    );
    _applyDerivedPolicies();
  }

  final RoomSessionRepository _roomSessionRepository;
  final VoidCallback _onChanged;
  final RoomSettingsRepository _settingsRepository =
      RoomSettingsRepository();

  final String _initialRoomName;
  final String _initialRoomId;
  final String _initialModeTitle;
  final bool _initialRoomImagesEnabled;
  final bool _initialGuestMessagesEnabled;
  final bool _initialApplyOnlyModeEnabled;
  final bool _initialAllowScreenshots;
  final RoomBackgroundTheme _initialBackgroundTheme;
  final String _initialSeatLayoutId;
  final String _initialAnnouncementText;

  bool _minimized = false;
  bool _allowRoomPop = false;
  bool _leaveSheetOpen = false;
  bool _exitingRoom = false;
  int _inboxUnreadCount;
  VibeSyncRoomState _vibeSyncState;
  Offset _bubbleOffset;

  Map<String, dynamic> get _room =>
      _roomSessionRepository.currentState.room;

  String get roomName =>
      _text(_room['name'] ?? _room['room_name']) ?? _initialRoomName;

  String get roomId {
    final canonical = _roomSessionRepository.currentState.roomId.trim();
    return canonical.isEmpty ? _initialRoomId : canonical;
  }

  RoomPrivacyMode get privacyMode {
    final mode = _text(_room['mode']);
    if (mode == null) return privacyModeFromTitle(_initialModeTitle);
    return privacyModeFromTitle(mode);
  }

  bool get roomImagesEnabled => _bool(
    _room['room_images_enabled'],
    fallback: _initialRoomImagesEnabled,
  );

  bool get guestMessagesEnabled => _bool(
    _room['guest_messages_enabled'],
    fallback: _initialGuestMessagesEnabled,
  );

  bool get applyOnlyModeEnabled => _bool(
    _room['apply_only_mode_enabled'],
    fallback: _initialApplyOnlyModeEnabled,
  );

  bool get allowScreenshots => _bool(
    _room['allow_screenshots'],
    fallback: _initialAllowScreenshots,
  );

  bool get minimized => _minimized;
  bool get allowRoomPop => _allowRoomPop;
  bool get leaveSheetOpen => _leaveSheetOpen;
  bool get exitingRoom => _exitingRoom;
  int get inboxUnreadCount => _inboxUnreadCount;
  VibeSyncRoomState get vibeSyncState => _vibeSyncState;
  Offset get bubbleOffset => _bubbleOffset;

  RoomBackgroundTheme get selectedBackgroundTheme {
    final themeId = _text(
      _room['background_theme_id'] ??
          _roomSessionRepository.currentState.media['background_theme_id'],
    );
    return _themeFromId(themeId ?? _initialBackgroundTheme.id);
  }

  String get seatLayoutId {
    return _text(
          _room['seat_layout_id'] ??
              _roomSessionRepository.currentState.stage['seat_layout_id'] ??
              _roomSessionRepository.currentState.media['seat_layout_id'],
        ) ??
        _initialSeatLayoutId;
  }

  String get announcementText =>
      _text(_room['announcement_text']) ?? _initialAnnouncementText;

  LiveRoomStateSnapshot snapshotForRestore() {
    return LiveRoomStateSnapshot(
      roomName: roomName,
      roomId: roomId,
      privacyMode: privacyMode,
      roomImagesEnabled: roomImagesEnabled,
      guestMessagesEnabled: guestMessagesEnabled,
      applyOnlyModeEnabled: applyOnlyModeEnabled,
      allowScreenshots: allowScreenshots,
      inboxUnreadCount: _inboxUnreadCount,
      vibeSyncState: _vibeSyncState,
      bubbleOffset: _bubbleOffset,
      selectedBackgroundTheme: selectedBackgroundTheme,
      seatLayoutId: seatLayoutId,
      announcementText: announcementText,
    );
  }

  void dispose() {
    ScreenshotGuardService.clear();
    _settingsRepository.close();
  }

  void renameRoom(String value) {
    unawaited(setRoomName(value));
  }

  Future<void> setRoomName(String value) async {
    final nextValue = value.trim();
    if (nextValue.isEmpty || nextValue == roomName) return;
    final settings = await _settingsRepository.updateRoomName(
      roomPublicId: roomId,
      name: nextValue,
    );
    _reconcileSettings(settings);
    LiveRoomMediaSignalingService.instance.configureRoom(
      roomId: roomId,
      roomName: roomName,
    );
  }

  /// Room identity is scoped by the Riverpod family key and therefore cannot
  /// mutate inside a mounted room session. Callers must create a new scoped
  /// room provider when navigating to another room.
  void updateRoomId(String value) {
    final nextValue = value.trim();
    if (nextValue.isEmpty || nextValue == roomId) return;
  }

  void setPrivacyMode(RoomPrivacyMode value) {
    unawaited(_setPrivacyMode(value));
  }

  Future<void> _setPrivacyMode(RoomPrivacyMode value) async {
    final settings = await _settingsRepository.updateAccessSettings(
      roomPublicId: roomId,
      mode: _privacyModeToBackendMode(value),
    );
    _reconcileSettings(settings);
  }

  void setAllowScreenshots(bool value) {
    unawaited(_setAllowScreenshots(value));
  }

  Future<void> _setAllowScreenshots(bool value) async {
    final settings = await _settingsRepository.updateAccessSettings(
      roomPublicId: roomId,
      allowScreenshots: value,
    );
    _reconcileSettings(settings);
  }

  void setRoomImagesEnabled(bool value) {
    LiveRoomMediaSignalingService.instance.setRoomImagesEnabled(value);
  }

  void setGuestMessagesEnabled(bool value) {
    LiveRoomMediaSignalingService.instance.setGuestMessagesEnabled(value);
  }

  void setApplyOnlyModeEnabled(bool value) {
    LiveRoomMediaSignalingService.instance.setRoomApplyOnlyMode(value);
  }

  void setMinimized(bool value) {
    if (value == _minimized) return;
    _minimized = value;
    _notify();
  }

  void setAllowRoomPop(bool value) {
    if (value == _allowRoomPop) return;
    _allowRoomPop = value;
    _notify();
  }

  void setLeaveSheetOpen(bool value) {
    if (value == _leaveSheetOpen) return;
    _leaveSheetOpen = value;
    _notify();
  }

  void setExitingRoom(bool value) {
    if (value == _exitingRoom) return;
    _exitingRoom = value;
    _notify();
  }

  void clearInboxUnreadCount() {
    if (_inboxUnreadCount == 0) return;
    _inboxUnreadCount = 0;
    _notify();
  }

  void setInboxUnreadCount(int value) {
    final nextValue = value < 0 ? 0 : value;
    if (nextValue == _inboxUnreadCount) return;
    _inboxUnreadCount = nextValue;
    _notify();
  }

  void setBubbleOffset(Offset value) {
    if (value == _bubbleOffset) return;
    _bubbleOffset = value;
    _notify();
  }

  void moveBubble({
    required Offset delta,
    required Size screenSize,
  }) {
    _bubbleOffset = Offset(
      (_bubbleOffset.dx + delta.dx).clamp(8.0, screenSize.width - 86),
      (_bubbleOffset.dy + delta.dy).clamp(40.0, screenSize.height - 120),
    );
    _notify();
  }

  void setSelectedBackgroundTheme(RoomBackgroundTheme value) {
    setRoomBackgroundTheme(value);
  }

  void setSeatLayoutId(String value) {
    final nextLayoutId = value.trim();
    if (nextLayoutId.isEmpty) return;
    unawaited(_setSeatLayoutId(nextLayoutId));
  }

  Future<void> _setSeatLayoutId(String value) async {
    final settings = await _settingsRepository.updateSeatLayout(
      roomPublicId: roomId,
      seatLayoutId: value,
    );
    _reconcileSettings(settings);
    RoomSeatLayoutSyncService.broadcastSeatLayout(
      roomId: roomId,
      seatLayoutId: settings.seatLayoutId,
    );
  }

  void setVibeSyncState(VibeSyncRoomState value) {
    if (value == _vibeSyncState) return;
    _vibeSyncState = value;
    _notify();
  }

  void clearVibeSyncOverlay() {
    final nextState = _vibeSyncState.copyWith(active: false);
    if (nextState == _vibeSyncState) return;
    _vibeSyncState = nextState;
    _notify();
  }

  Future<void> loadPersistedRoomSettings() async {
    try {
      final settings =
          await _settingsRepository.fetchRoomSettings(roomId);
      _reconcileSettings(settings);
    } catch (_) {
      _applyDerivedPolicies();
      // Settings are non-critical for room entry. Canonical snapshot/realtime
      // state remains the authority and will converge after reconnect.
    }
  }

  void setRoomBackgroundTheme(RoomBackgroundTheme value) {
    if (value.id == selectedBackgroundTheme.id) return;
    unawaited(_setRoomBackgroundTheme(value));
  }

  Future<void> _setRoomBackgroundTheme(
    RoomBackgroundTheme value,
  ) async {
    final settings = await _settingsRepository.updateBackground(
      roomPublicId: roomId,
      backgroundThemeId: value.id,
    );
    _reconcileSettings(settings);
    LiveRoomMediaSignalingService.instance.setRoomBackgroundTheme(
      settings.backgroundThemeId,
    );
  }

  Future<void> setRoomAnnouncement(String value) async {
    final nextValue = value.trim();
    if (nextValue == announcementText) return;
    final settings = await _settingsRepository.updateAnnouncement(
      roomPublicId: roomId,
      announcementText: nextValue,
    );
    _reconcileSettings(settings);
    LiveRoomMediaSignalingService.instance.setRoomAnnouncement(
      settings.announcementText ?? '',
    );
  }

  void applyCanonicalRoomState() {
    _applyDerivedPolicies();
    _notify();
  }

  void resetForLeaveFlow() {
    _allowRoomPop = false;
    _leaveSheetOpen = false;
    _exitingRoom = false;
    _minimized = false;
    _notify();
  }

  void _reconcileSettings(RoomSettingsDto settings) {
    _roomSessionRepository.reconcileDelta(<String, dynamic>{
      'room_id': roomId,
      if (settings.name?.trim().isNotEmpty == true)
        'name': settings.name!.trim(),
      if (settings.language?.trim().isNotEmpty == true)
        'language': settings.language!.trim(),
      if (settings.mode?.trim().isNotEmpty == true)
        'mode': settings.mode!.trim(),
      'is_secret': settings.isSecret,
      'is_locked': settings.isLocked,
      'is_members_only': settings.isMembersOnly,
      'allow_screenshots': settings.allowScreenshots,
      'room_images_enabled': settings.roomImagesEnabled,
      'guest_messages_enabled': settings.guestMessagesEnabled,
      'apply_only_mode_enabled': settings.applyOnlyModeEnabled,
      'background_theme_id': settings.backgroundThemeId,
      'seat_layout_id': settings.seatLayoutId,
      'announcement_text': settings.announcementText ?? '',
    });
    _applyDerivedPolicies();
    _notify();
  }

  void _applyDerivedPolicies() {
    ScreenshotGuardService.applyRoomScreenshotPolicy(
      allowScreenshots: allowScreenshots,
    );
  }

  RoomBackgroundTheme _themeFromId(String themeId) {
    final cleanId = themeId.trim();
    return <RoomBackgroundTheme>[
      ...ownedRoomBackgroundThemes,
      ...cricketModeBackgroundThemes,
      ...cricketRoomBackgroundThemes,
    ].firstWhere(
      (theme) => theme.id == cleanId,
      orElse: () => _initialBackgroundTheme,
    );
  }

  String _privacyModeToBackendMode(RoomPrivacyMode value) {
    switch (value) {
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

  void _notify() => _onChanged();
}

class LiveRoomStateSnapshot {
  const LiveRoomStateSnapshot({
    required this.roomName,
    required this.roomId,
    required this.privacyMode,
    required this.roomImagesEnabled,
    required this.guestMessagesEnabled,
    required this.applyOnlyModeEnabled,
    required this.allowScreenshots,
    required this.inboxUnreadCount,
    required this.vibeSyncState,
    required this.bubbleOffset,
    required this.selectedBackgroundTheme,
    required this.seatLayoutId,
    required this.announcementText,
  });

  final String roomName;
  final String roomId;
  final RoomPrivacyMode privacyMode;
  final bool roomImagesEnabled;
  final bool guestMessagesEnabled;
  final bool applyOnlyModeEnabled;
  final bool allowScreenshots;
  final int inboxUnreadCount;
  final VibeSyncRoomState vibeSyncState;
  final Offset bubbleOffset;
  final RoomBackgroundTheme selectedBackgroundTheme;
  final String seatLayoutId;
  final String announcementText;
}

String? _text(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}

bool _bool(Object? value, {required bool fallback}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized == 'true' ||
      normalized == '1' ||
      normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' ||
      normalized == '0' ||
      normalized == 'no') {
    return false;
  }
  return fallback;
}
