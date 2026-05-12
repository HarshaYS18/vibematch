import 'package:flutter/material.dart';

import '../../data/live_room_media_signaling_service.dart';
import '../../data/live_room_settings_event_bus.dart';
import '../../data/room_settings_repository.dart';
import '../live_room_models.dart';
import '../widgets/room_theme.dart';
import '../widgets/vibesync_room_module.dart';

class LiveRoomStateController extends ChangeNotifier {
  LiveRoomStateController({
    required String initialRoomName,
    required String initialRoomId,
    required String initialModeTitle,
    int initialInboxUnreadCount = 4,
  }) : _roomName = initialRoomName,
       _roomId = initialRoomId,
       _privacyMode = privacyModeFromTitle(initialModeTitle),
       _inboxUnreadCount = initialInboxUnreadCount {
    LiveRoomMediaSignalingService.instance.configureRoom(
      roomId: _roomId,
      roomName: _roomName,
    );
    LiveRoomSettingsEventBus.latestEvent.addListener(
      _handleRealtimeSettingsEvent,
    );
  }

  String _roomName;
  String _roomId;
  RoomPrivacyMode _privacyMode;
  bool _roomImagesEnabled = true;
  bool _guestMessagesEnabled = true;
  bool _applyOnlyModeEnabled = false;
  bool _minimized = false;
  bool _allowRoomPop = false;
  bool _leaveSheetOpen = false;
  bool _exitingRoom = false;
  int _inboxUnreadCount;
  VibeSyncRoomState _vibeSyncState = VibeSyncRoomState.inactive;
  Offset _bubbleOffset = const Offset(24, 120);
  final RoomSettingsRepository _settingsRepository = RoomSettingsRepository();
  RoomBackgroundTheme _selectedBackgroundTheme = defaultRoomBackgroundTheme;
  String _announcementText = '';

  String get roomName => _roomName;
  String get roomId => _roomId;
  RoomPrivacyMode get privacyMode => _privacyMode;
  bool get roomImagesEnabled => _roomImagesEnabled;
  bool get guestMessagesEnabled => _guestMessagesEnabled;
  bool get applyOnlyModeEnabled => _applyOnlyModeEnabled;
  bool get minimized => _minimized;
  bool get allowRoomPop => _allowRoomPop;
  bool get leaveSheetOpen => _leaveSheetOpen;
  bool get exitingRoom => _exitingRoom;
  int get inboxUnreadCount => _inboxUnreadCount;
  VibeSyncRoomState get vibeSyncState => _vibeSyncState;
  Offset get bubbleOffset => _bubbleOffset;
  RoomBackgroundTheme get selectedBackgroundTheme => _selectedBackgroundTheme;
  String get announcementText => _announcementText;

  @override
  void dispose() {
    LiveRoomSettingsEventBus.latestEvent.removeListener(
      _handleRealtimeSettingsEvent,
    );
    super.dispose();
  }

  void _handleRealtimeSettingsEvent() {
    final event = LiveRoomSettingsEventBus.latestEvent.value;
    if (event == null) return;
    if (event.roomId.trim().isNotEmpty && event.roomId != _roomId) return;
    var changed = false;

    if (event.applyOnlyModeEnabled != _applyOnlyModeEnabled) {
      _applyOnlyModeEnabled = event.applyOnlyModeEnabled;
      changed = true;
    }

    if (event.backgroundThemeId.trim().isNotEmpty) {
      final nextTheme = _themeFromId(event.backgroundThemeId);
      if (nextTheme != _selectedBackgroundTheme) {
        _selectedBackgroundTheme = nextTheme;
        changed = true;
      }
    }

    if (event.announcementText != _announcementText) {
      _announcementText = event.announcementText;
      changed = true;
    }

    if (changed) notifyListeners();
  }

  void renameRoom(String value) {
    final nextValue = value.trim();
    if (nextValue.isEmpty || nextValue == _roomName) return;
    _roomName = nextValue;
    LiveRoomMediaSignalingService.instance.configureRoom(
      roomId: _roomId,
      roomName: _roomName,
    );
    notifyListeners();
  }

  void updateRoomId(String value) {
    final nextValue = value.trim();
    if (nextValue.isEmpty || nextValue == _roomId) return;
    _roomId = nextValue;
    LiveRoomMediaSignalingService.instance.configureRoom(
      roomId: _roomId,
      roomName: _roomName,
    );
    notifyListeners();
  }

  void setPrivacyMode(RoomPrivacyMode value) {
    if (value == _privacyMode) return;
    _privacyMode = value;
    notifyListeners();
  }

  void setRoomImagesEnabled(bool value) {
    if (value == _roomImagesEnabled) return;
    _roomImagesEnabled = value;
    notifyListeners();
  }

  void setGuestMessagesEnabled(bool value) {
    if (value == _guestMessagesEnabled) return;
    _guestMessagesEnabled = value;
    notifyListeners();
  }

  void setApplyOnlyModeEnabled(bool value) {
    if (value == _applyOnlyModeEnabled) return;
    _applyOnlyModeEnabled = value;
    LiveRoomMediaSignalingService.instance.setRoomApplyOnlyMode(value);
    notifyListeners();
  }

  void setMinimized(bool value) {
    if (value == _minimized) return;
    _minimized = value;
    notifyListeners();
  }

  void setAllowRoomPop(bool value) {
    if (value == _allowRoomPop) return;
    _allowRoomPop = value;
    notifyListeners();
  }

  void setLeaveSheetOpen(bool value) {
    if (value == _leaveSheetOpen) return;
    _leaveSheetOpen = value;
    notifyListeners();
  }

  void setExitingRoom(bool value) {
    if (value == _exitingRoom) return;
    _exitingRoom = value;
    notifyListeners();
  }

  void clearInboxUnreadCount() {
    if (_inboxUnreadCount == 0) return;
    _inboxUnreadCount = 0;
    notifyListeners();
  }

  void setInboxUnreadCount(int value) {
    final nextValue = value < 0 ? 0 : value;
    if (nextValue == _inboxUnreadCount) return;
    _inboxUnreadCount = nextValue;
    notifyListeners();
  }

  void setBubbleOffset(Offset value) {
    if (value == _bubbleOffset) return;
    _bubbleOffset = value;
    notifyListeners();
  }

  void moveBubble({required Offset delta, required Size screenSize}) {
    _bubbleOffset = Offset(
      (_bubbleOffset.dx + delta.dx).clamp(8.0, screenSize.width - 86),
      (_bubbleOffset.dy + delta.dy).clamp(40.0, screenSize.height - 120),
    );
    notifyListeners();
  }

  void setSelectedBackgroundTheme(RoomBackgroundTheme value) {
    setRoomBackgroundTheme(value);
  }

  void setVibeSyncState(VibeSyncRoomState value) {
    if (value == _vibeSyncState) return;
    _vibeSyncState = value;
    notifyListeners();
  }

  void clearVibeSyncOverlay() {
    final nextState = _vibeSyncState.copyWith(active: false);
    if (nextState == _vibeSyncState) return;
    _vibeSyncState = nextState;
    notifyListeners();
  }

  Future<void> loadPersistedRoomSettings() async {
    try {
      final settings = await _settingsRepository.fetchRoomSettings(_roomId);
      var changed = false;

      final theme = _themeFromId(settings.backgroundThemeId);
      if (theme != _selectedBackgroundTheme) {
        _selectedBackgroundTheme = theme;
        changed = true;
      }

      final announcement = settings.announcementText ?? '';
      if (announcement != _announcementText) {
        _announcementText = announcement;
        changed = true;
      }

      if (changed) notifyListeners();
    } catch (_) {
      // Room settings are non-critical for room entry.
    }
  }

  RoomBackgroundTheme _themeFromId(String themeId) {
    final cleanId = themeId.trim();
    if (cleanId.isEmpty) return _selectedBackgroundTheme;
    return ownedRoomBackgroundThemes.firstWhere(
      (theme) => theme.id == cleanId,
      orElse: () => _selectedBackgroundTheme,
    );
  }

  void setRoomBackgroundTheme(RoomBackgroundTheme value) {
    if (value == _selectedBackgroundTheme) return;
    _selectedBackgroundTheme = value;
    notifyListeners();

    _settingsRepository
        .updateBackground(roomPublicId: _roomId, backgroundThemeId: value.id)
        .then((settings) {
          final theme = _themeFromId(settings.backgroundThemeId);
          if (theme != _selectedBackgroundTheme) {
            _selectedBackgroundTheme = theme;
            notifyListeners();
          }
          LiveRoomMediaSignalingService.instance.setRoomBackgroundTheme(
            settings.backgroundThemeId,
          );
        })
        .catchError((_) {
          LiveRoomMediaSignalingService.instance.setRoomBackgroundTheme(
            value.id,
          );
        });
  }

  void setRoomAnnouncement(String value) {
    final nextValue = value.trim();
    if (nextValue == _announcementText) return;
    _announcementText = nextValue;
    notifyListeners();

    _settingsRepository
        .updateAnnouncement(roomPublicId: _roomId, announcementText: nextValue)
        .then((settings) {
          final announcement = settings.announcementText ?? '';
          if (announcement != _announcementText) {
            _announcementText = announcement;
            notifyListeners();
          }
          LiveRoomMediaSignalingService.instance.setRoomAnnouncement(
            announcement,
          );
        })
        .catchError((_) {
          LiveRoomMediaSignalingService.instance.setRoomAnnouncement(nextValue);
        });
  }

  void resetForLeaveFlow() {
    _allowRoomPop = false;
    _leaveSheetOpen = false;
    _exitingRoom = false;
    _minimized = false;
    notifyListeners();
  }
}
