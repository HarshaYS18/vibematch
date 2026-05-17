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
      _autoOccupySeatOneForHostOrAdmin();
    }
    if (mounted) _setRoomState(() {});
  }

  void _autoOccupySeatOneForHostOrAdmin() {
    _hostSeatOneTimer?.cancel();
    _hostSeatOneRetryTimer?.cancel();

    if (!_viewerCanManageRoom) return;

    _hostSeatOneTimer = Timer(
      const Duration(milliseconds: 260),
      _tryOccupySeatOneForHostOrAdmin,
    );
    _hostSeatOneRetryTimer = Timer(
      const Duration(milliseconds: 1300),
      _tryOccupySeatOneForHostOrAdmin,
    );
  }

  void _tryOccupySeatOneForHostOrAdmin() {
    if (!mounted || !_viewerCanManageRoom) return;
    if (_seatController.seats.isEmpty) return;

    if (_seatController.currentUserIsSeated) {
      _hostSeatOneTimer?.cancel();
      _hostSeatOneRetryTimer?.cancel();
      return;
    }

    final firstSeat = _seatController.seats.first;
    if (firstSeat.locked) return;
    if (firstSeat.user != null) return;

    _seatController.occupySeat(0);
  }
}