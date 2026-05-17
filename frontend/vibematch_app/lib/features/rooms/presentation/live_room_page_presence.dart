part of 'live_room_page.dart';

extension _LiveRoomPagePresence on _LiveRoomPageState {
  bool get _isSecretPresenceRoom {
    final mode = widget.modeTitle.toLowerCase();
    final privacy = _privacyMode.toString().toLowerCase();
    return mode.contains('secret') || privacy.contains('secret');
  }

  void _startRoomPresence() {
    _presenceController.start(
      roomPublicId: _roomId,
      roomName: _roomName,
      roomMode: widget.modeTitle,
      isSecret: _isSecretPresenceRoom,
    );
  }

  void _syncPresenceRoomDetails() {
    _presenceController.updateRoom(
      roomPublicId: _roomId,
      roomName: _roomName,
      roomMode: widget.modeTitle,
      isSecret: _isSecretPresenceRoom,
    );
  }

  void _onRoomStateChanged() {
    _syncPresenceRoomDetails();
    final syncedLayout = _roomStateController.seatLayoutId;
    if (syncedLayout.trim().isNotEmpty && syncedLayout != _seatController.layoutId) {
      _seatController.changeLayout(syncedLayout);
    }
    if (mounted) _setRoomState(() {});
  }

  void _autoOccupySeatOneForHostOrAdmin() {
    // Production rule:
    // Entering or re-entering a room must not auto-occupy a seat.
    // The backend snapshot is the only source of truth for whether the user is
    // seated. A user becomes seated only through an explicit seat/take command.
    _hostSeatOneTimer?.cancel();
    _hostSeatOneRetryTimer?.cancel();
  }

  void _tryOccupySeatOneForHostOrAdmin() {
    // Intentionally disabled. See _autoOccupySeatOneForHostOrAdmin.
  }
}