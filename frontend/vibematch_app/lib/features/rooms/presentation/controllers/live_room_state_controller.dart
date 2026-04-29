import 'package:flutter/material.dart';

import '../live_room_models.dart';
import '../widgets/room_theme.dart';
import '../widgets/vibesync_room_module.dart';

class LiveRoomStateController extends ChangeNotifier {
  LiveRoomStateController({
    required String initialRoomName,
    required String initialRoomId,
    required String initialModeTitle,
    int initialInboxUnreadCount = 4,
  })  : _roomName = initialRoomName,
        _roomId = initialRoomId,
        _privacyMode = privacyModeFromTitle(initialModeTitle),
        _inboxUnreadCount = initialInboxUnreadCount;

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
  RoomBackgroundTheme _selectedBackgroundTheme = defaultRoomBackgroundTheme;

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

  void renameRoom(String value) {
    final nextValue = value.trim();
    if (nextValue.isEmpty || nextValue == _roomName) return;
    _roomName = nextValue;
    notifyListeners();
  }

  void updateRoomId(String value) {
    final nextValue = value.trim();
    if (nextValue.isEmpty || nextValue == _roomId) return;
    _roomId = nextValue;
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

  void moveBubble({
    required Offset delta,
    required Size screenSize,
  }) {
    _bubbleOffset = Offset(
      (_bubbleOffset.dx + delta.dx).clamp(8.0, screenSize.width - 86),
      (_bubbleOffset.dy + delta.dy).clamp(40.0, screenSize.height - 120),
    );
    notifyListeners();
  }

  void setSelectedBackgroundTheme(RoomBackgroundTheme value) {
    if (value == _selectedBackgroundTheme) return;
    _selectedBackgroundTheme = value;
    notifyListeners();
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

  void resetForLeaveFlow() {
    _allowRoomPop = false;
    _leaveSheetOpen = false;
    _exitingRoom = false;
    _minimized = false;
    notifyListeners();
  }
}
