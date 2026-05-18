import 'package:flutter/material.dart';

import '../../../../core/security/screenshot_guard_service.dart';
import '../../data/active_room_context.dart';
import '../../data/live_room_media_signaling_service.dart';
import '../../data/live_room_restrictions_service.dart';
import '../../data/live_room_settings_event_bus.dart';
import '../../data/room_seat_layout_sync_service.dart';
import '../../data/room_settings_repository.dart';
import '../live_room_models.dart';
import '../modules/cricket_mode_module.dart';
import '../widgets/cricket_room_backgrounds.dart';
import '../widgets/room_theme.dart';
import '../widgets/vibesync_room_module.dart';

class LiveRoomStateController extends ChangeNotifier {
  LiveRoomStateController({
    required String initialRoomName,
    required String initialRoomId,
    required String initialModeTitle,
    RoomBackgroundTheme? initialBackgroundTheme,
    LiveRoomStateSnapshot? initialStateSnapshot,
    bool preserveInitialBackgroundOnFirstLoad = false,
    int initialInboxUnreadCount = 4,
  }) : _roomName = initialRoomName,
       _roomId = initialRoomId,
       _privacyMode = privacyModeFromTitle(initialModeTitle),
       _selectedBackgroundTheme =
           initialBackgroundTheme ?? defaultRoomBackgroundTheme,
       _preserveInitialBackgroundOnFirstLoad =
           preserveInitialBackgroundOnFirstLoad,
       _inboxUnreadCount = initialInboxUnreadCount {
    final restoreState = initialStateSnapshot;
    if (restoreState != null) {
      _roomName = restoreState.roomName;
      _roomId = restoreState.roomId;
      _privacyMode = restoreState.privacyMode;
      _roomImagesEnabled = restoreState.roomImagesEnabled;
      _guestMessagesEnabled = restoreState.guestMessagesEnabled;
      _applyOnlyModeEnabled = restoreState.applyOnlyModeEnabled;
      _allowScreenshots = restoreState.allowScreenshots;
      _inboxUnreadCount = restoreState.inboxUnreadCount;
      _vibeSyncState = restoreState.vibeSyncState;
      _bubbleOffset = restoreState.bubbleOffset;
      _selectedBackgroundTheme = restoreState.selectedBackgroundTheme;
      _seatLayoutId = restoreState.seatLayoutId;
      _announcementText = restoreState.announcementText;
      _preserveInitialSnapshotOnFirstLoad = true;
      _preserveInitialBackgroundOnFirstLoad = true;
    }
    _syncRoomIdentity();
    activeRoomBackgroundTheme.value = _selectedBackgroundTheme;
    LiveRoomRestrictionsService.update(
      roomImagesEnabled: _roomImagesEnabled,
      guestMessagesEnabled: _guestMessagesEnabled,
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
  bool _allowScreenshots = true;
  bool _minimized = false;
  bool _allowRoomPop = false;
  bool _leaveSheetOpen = false;
  bool _exitingRoom = false;
  int _inboxUnreadCount;
  VibeSyncRoomState _vibeSyncState = VibeSyncRoomState.inactive;
  Offset _bubbleOffset = const Offset(24, 120);
  final RoomSettingsRepository _settingsRepository = RoomSettingsRepository();
  RoomBackgroundTheme _selectedBackgroundTheme;
  bool _preserveInitialBackgroundOnFirstLoad;
  bool _preserveInitialSnapshotOnFirstLoad = false;
  String _seatLayoutId = '5x2';
  String _announcementText = '';

  String get roomName => _roomName;
  String get roomId => _roomId;
  RoomPrivacyMode get privacyMode => _privacyMode;
  bool get roomImagesEnabled => _roomImagesEnabled;
  bool get guestMessagesEnabled => _guestMessagesEnabled;
  bool get applyOnlyModeEnabled => _applyOnlyModeEnabled;
  bool get allowScreenshots => _allowScreenshots;
  bool get minimized => _minimized;
  bool get allowRoomPop => _allowRoomPop;
  bool get leaveSheetOpen => _leaveSheetOpen;
  bool get exitingRoom => _exitingRoom;
  int get inboxUnreadCount => _inboxUnreadCount;
  VibeSyncRoomState get vibeSyncState => _vibeSyncState;
  Offset get bubbleOffset => _bubbleOffset;
  RoomBackgroundTheme get selectedBackgroundTheme => _selectedBackgroundTheme;
  String get seatLayoutId => _seatLayoutId;
  String get announcementText => _announcementText;

  LiveRoomStateSnapshot snapshotForRestore() {
    return LiveRoomStateSnapshot(
      roomName: _roomName,
      roomId: _roomId,
      privacyMode: _privacyMode,
      roomImagesEnabled: _roomImagesEnabled,
      guestMessagesEnabled: _guestMessagesEnabled,
      applyOnlyModeEnabled: _applyOnlyModeEnabled,
      allowScreenshots: _allowScreenshots,
      inboxUnreadCount: _inboxUnreadCount,
      vibeSyncState: _vibeSyncState,
      bubbleOffset: _bubbleOffset,
      selectedBackgroundTheme: _selectedBackgroundTheme,
      seatLayoutId: _seatLayoutId,
      announcementText: _announcementText,
    );
  }

  @override
  void dispose() {
    LiveRoomSettingsEventBus.latestEvent.removeListener(
      _handleRealtimeSettingsEvent,
    );
    ActiveRoomContext.clearIfMatches(_roomId);
    ScreenshotGuardService.clear();
    super.dispose();
  }

  void _handleRealtimeSettingsEvent() {
    final event = LiveRoomSettingsEventBus.latestEvent.value;
    if (event == null) return;
    if (event.roomId.trim().isNotEmpty && event.roomId != _roomId) return;
    var changed = false;
    var restrictionsChanged = false;

    final nextRoomName = event.roomName.trim();
    if (nextRoomName.isNotEmpty && nextRoomName != _roomName) {
      _applyRoomName(nextRoomName, notify: false);
      changed = true;
    }

    final nextApplyOnlyModeEnabled = event.applyOnlyModeEnabled;
    if (nextApplyOnlyModeEnabled != null &&
        nextApplyOnlyModeEnabled != _applyOnlyModeEnabled) {
      _applyOnlyModeEnabled = nextApplyOnlyModeEnabled;
      changed = true;
    }

    final nextRoomImagesEnabled = event.roomImagesEnabled;
    if (nextRoomImagesEnabled != null &&
        nextRoomImagesEnabled != _roomImagesEnabled) {
      _roomImagesEnabled = nextRoomImagesEnabled;
      changed = true;
      restrictionsChanged = true;
    }

    final nextGuestMessagesEnabled = event.guestMessagesEnabled;
    if (nextGuestMessagesEnabled != null &&
        nextGuestMessagesEnabled != _guestMessagesEnabled) {
      _guestMessagesEnabled = nextGuestMessagesEnabled;
      changed = true;
      restrictionsChanged = true;
    }

    if (event.privacyModeTitle.trim().isNotEmpty) {
      final nextPrivacyMode = privacyModeFromTitle(event.privacyModeTitle);
      if (nextPrivacyMode != _privacyMode) {
        _privacyMode = nextPrivacyMode;
        changed = true;
      }
    }

    final nextAllowScreenshots = event.allowScreenshots;
    if (nextAllowScreenshots != null &&
        nextAllowScreenshots != _allowScreenshots) {
      _allowScreenshots = nextAllowScreenshots;
      ScreenshotGuardService.applyRoomScreenshotPolicy(
        allowScreenshots: _allowScreenshots,
      );
      changed = true;
    }

    if (event.backgroundThemeId.trim().isNotEmpty) {
      final nextTheme = _themeFromId(event.backgroundThemeId);
      if (nextTheme != _selectedBackgroundTheme) {
        _selectedBackgroundTheme = nextTheme;
        activeRoomBackgroundTheme.value = nextTheme;
        changed = true;
      }
    }

    if (event.seatLayoutId.trim().isNotEmpty &&
        event.seatLayoutId != _seatLayoutId) {
      _seatLayoutId = event.seatLayoutId.trim();
      changed = true;
    }

    if (event.announcementText != _announcementText &&
        event.announcementText.trim().isNotEmpty) {
      _announcementText = event.announcementText;
      changed = true;
    }

    if (changed) {
      if (restrictionsChanged) {
        LiveRoomRestrictionsService.update(
          roomImagesEnabled: _roomImagesEnabled,
          guestMessagesEnabled: _guestMessagesEnabled,
        );
      }
      notifyListeners();
    }
  }

  void _syncRoomIdentity() {
    ActiveRoomContext.setActiveRoom(roomPublicId: _roomId, roomName: _roomName);
    LiveRoomMediaSignalingService.instance.configureRoom(
      roomId: _roomId,
      roomName: _roomName,
    );
  }

  void _applyRoomName(String value, {bool notify = true}) {
    final nextValue = value.trim();
    if (nextValue.isEmpty || nextValue == _roomName) return;
    _roomName = nextValue;
    _syncRoomIdentity();
    if (notify) notifyListeners();
  }

  void renameRoom(String value) => _applyRoomName(value);

  Future<void> setRoomName(String value) async {
    final nextValue = value.trim();
    if (nextValue.isEmpty || nextValue == _roomName) return;
    final previousName = _roomName;
    _applyRoomName(nextValue);
    try {
      final settings = await _settingsRepository.updateRoomName(
        roomPublicId: _roomId,
        name: nextValue,
      );
      final serverName = settings.name?.trim();
      if (serverName != null && serverName.isNotEmpty) {
        _applyRoomName(serverName);
      }
    } catch (_) {
      _applyRoomName(previousName);
      rethrow;
    }
  }

  void updateRoomId(String value) {
    final nextValue = value.trim();
    if (nextValue.isEmpty || nextValue == _roomId) return;
    final oldRoomId = _roomId;
    _roomId = nextValue;
    ActiveRoomContext.clearIfMatches(oldRoomId);
    _syncRoomIdentity();
    notifyListeners();
  }

  void setPrivacyMode(RoomPrivacyMode value) {
    final mode = _privacyModeToBackendMode(value);
    _settingsRepository
        .updateAccessSettings(roomPublicId: _roomId, mode: mode)
        .then(_applySettingsFromRest)
        .catchError((_) {});
  }

  void setAllowScreenshots(bool value) {
    _settingsRepository
        .updateAccessSettings(
          roomPublicId: _roomId,
          allowScreenshots: value,
        )
        .then(_applySettingsFromRest)
        .catchError((_) {});
  }

  void setRoomImagesEnabled(bool value) {
    if (_roomImagesEnabled != value) {
      _roomImagesEnabled = value;
      LiveRoomRestrictionsService.update(
        roomImagesEnabled: _roomImagesEnabled,
        guestMessagesEnabled: _guestMessagesEnabled,
      );
      notifyListeners();
    }
    LiveRoomMediaSignalingService.instance.setRoomImagesEnabled(value);
  }

  void setGuestMessagesEnabled(bool value) {
    if (_guestMessagesEnabled != value) {
      _guestMessagesEnabled = value;
      LiveRoomRestrictionsService.update(
        roomImagesEnabled: _roomImagesEnabled,
        guestMessagesEnabled: _guestMessagesEnabled,
      );
      notifyListeners();
    }
    LiveRoomMediaSignalingService.instance.setGuestMessagesEnabled(value);
  }

  void setApplyOnlyModeEnabled(bool value) {
    if (_applyOnlyModeEnabled != value) {
      _applyOnlyModeEnabled = value;
      notifyListeners();
    }
    LiveRoomMediaSignalingService.instance.setRoomApplyOnlyMode(value);
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

  void setSeatLayoutId(String value) {
    final nextLayoutId = value.trim();
    if (nextLayoutId.isEmpty) return;
    if (nextLayoutId == _seatLayoutId) {
      RoomSeatLayoutSyncService.broadcastSeatLayout(
        roomId: _roomId,
        seatLayoutId: nextLayoutId,
      );
      return;
    }
    _seatLayoutId = nextLayoutId;
    notifyListeners();

    _settingsRepository
        .updateSeatLayout(roomPublicId: _roomId, seatLayoutId: nextLayoutId)
        .then((settings) {
          if (settings.seatLayoutId != _seatLayoutId) {
            _seatLayoutId = settings.seatLayoutId;
            notifyListeners();
          }
          RoomSeatLayoutSyncService.broadcastSeatLayout(
            roomId: _roomId,
            seatLayoutId: settings.seatLayoutId,
          );
        })
        .catchError((_) {
          RoomSeatLayoutSyncService.broadcastSeatLayout(
            roomId: _roomId,
            seatLayoutId: nextLayoutId,
          );
        });
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
      _preserveInitialSnapshotOnFirstLoad = false;
      _applySettingsFromRest(settings, preserveInitialSnapshot: true);
    } catch (_) {
      _preserveInitialSnapshotOnFirstLoad = false;
      ScreenshotGuardService.applyRoomScreenshotPolicy(
        allowScreenshots: _allowScreenshots,
      );
      // Room settings are non-critical for room entry.
    }
  }

  void _applySettingsFromRest(
    RoomSettingsDto settings, {
    bool preserveInitialSnapshot = false,
  }) {
    var changed = false;
    var restrictionsChanged = false;
    final preserveInitial = preserveInitialSnapshot || _preserveInitialSnapshotOnFirstLoad;

    final nextRoomName = settings.name?.trim();
    if (nextRoomName != null && nextRoomName.isNotEmpty && nextRoomName != _roomName) {
      _applyRoomName(nextRoomName, notify: false);
      changed = true;
    }

    final backgroundThemeId = settings.backgroundThemeId.trim();
    final theme = _themeFromId(backgroundThemeId);
    final shouldPreserveInitialBackground =
        (_preserveInitialBackgroundOnFirstLoad || preserveInitial) &&
        _selectedBackgroundTheme.id != defaultRoomBackgroundTheme.id &&
        (backgroundThemeId.isEmpty ||
            backgroundThemeId == defaultRoomBackgroundTheme.id);
    _preserveInitialBackgroundOnFirstLoad = false;
    if (!shouldPreserveInitialBackground && theme != _selectedBackgroundTheme) {
      _selectedBackgroundTheme = theme;
      activeRoomBackgroundTheme.value = theme;
      changed = true;
    }

    final shouldPreserveInitialSeatLayout =
        preserveInitial &&
        _seatLayoutId != '5x2' &&
        (settings.seatLayoutId.trim().isEmpty || settings.seatLayoutId == '5x2');
    if (settings.seatLayoutId.trim().isNotEmpty &&
        !shouldPreserveInitialSeatLayout &&
        settings.seatLayoutId != _seatLayoutId) {
      _seatLayoutId = settings.seatLayoutId;
      changed = true;
    }

    final announcement = settings.announcementText ?? '';
    final shouldPreserveInitialAnnouncement =
        preserveInitial &&
        _announcementText.trim().isNotEmpty &&
        announcement.trim().isEmpty;
    if (!shouldPreserveInitialAnnouncement && announcement != _announcementText) {
      _announcementText = announcement;
      changed = true;
    }

    final mode = settings.mode;
    if (mode != null && mode.trim().isNotEmpty) {
      final nextPrivacy = privacyModeFromTitle(mode);
      final shouldPreserveInitialPrivacy =
          preserveInitial &&
          _privacyMode != RoomPrivacyMode.open &&
          nextPrivacy == RoomPrivacyMode.open;
      if (!shouldPreserveInitialPrivacy && nextPrivacy != _privacyMode) {
        _privacyMode = nextPrivacy;
        changed = true;
      }
    }

    final shouldPreserveInitialScreenshotPolicy =
        preserveInitial && !_allowScreenshots && settings.allowScreenshots;
    if (!shouldPreserveInitialScreenshotPolicy &&
        settings.allowScreenshots != _allowScreenshots) {
      _allowScreenshots = settings.allowScreenshots;
      ScreenshotGuardService.applyRoomScreenshotPolicy(
        allowScreenshots: _allowScreenshots,
      );
      changed = true;
    } else {
      ScreenshotGuardService.applyRoomScreenshotPolicy(
        allowScreenshots: _allowScreenshots,
      );
    }

    if (settings.roomImagesEnabled != _roomImagesEnabled) {
      _roomImagesEnabled = settings.roomImagesEnabled;
      changed = true;
      restrictionsChanged = true;
    }

    if (settings.guestMessagesEnabled != _guestMessagesEnabled) {
      _guestMessagesEnabled = settings.guestMessagesEnabled;
      changed = true;
      restrictionsChanged = true;
    }

    if (settings.applyOnlyModeEnabled != _applyOnlyModeEnabled) {
      _applyOnlyModeEnabled = settings.applyOnlyModeEnabled;
      changed = true;
    }

    _preserveInitialSnapshotOnFirstLoad = false;
    if (restrictionsChanged) {
      LiveRoomRestrictionsService.update(
        roomImagesEnabled: _roomImagesEnabled,
        guestMessagesEnabled: _guestMessagesEnabled,
      );
    }
    if (changed) notifyListeners();
  }

  RoomBackgroundTheme _themeFromId(String themeId) {
    final cleanId = themeId.trim();
    if (cleanId.isEmpty) return _selectedBackgroundTheme;
    return <RoomBackgroundTheme>[
      ...ownedRoomBackgroundThemes,
      ...cricketModeBackgroundThemes,
      ...cricketRoomBackgroundThemes,
    ].firstWhere(
      (theme) => theme.id == cleanId,
      orElse: () => _selectedBackgroundTheme,
    );
  }

  void setRoomBackgroundTheme(RoomBackgroundTheme value) {
    if (value == _selectedBackgroundTheme) return;
    _selectedBackgroundTheme = value;
    activeRoomBackgroundTheme.value = value;
    notifyListeners();

    _settingsRepository
        .updateBackground(roomPublicId: _roomId, backgroundThemeId: value.id)
        .then((settings) {
          final theme = _themeFromId(settings.backgroundThemeId);
          if (theme != _selectedBackgroundTheme) {
            _selectedBackgroundTheme = theme;
            activeRoomBackgroundTheme.value = theme;
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

  Future<void> setRoomAnnouncement(String value) async {
    final nextValue = value.trim();
    if (nextValue == _announcementText) return;
    final previousAnnouncement = _announcementText;
    _announcementText = nextValue;
    notifyListeners();

    try {
      final settings = await _settingsRepository.updateAnnouncement(
        roomPublicId: _roomId,
        announcementText: nextValue,
      );
      final announcement = settings.announcementText ?? '';
      if (announcement != _announcementText) {
        _announcementText = announcement;
        notifyListeners();
      }
      LiveRoomMediaSignalingService.instance.setRoomAnnouncement(announcement);
    } catch (_) {
      _announcementText = previousAnnouncement;
      notifyListeners();
      rethrow;
    }
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

  void resetForLeaveFlow() {
    _allowRoomPop = false;
    _leaveSheetOpen = false;
    _exitingRoom = false;
    _minimized = false;
    notifyListeners();
  }
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
