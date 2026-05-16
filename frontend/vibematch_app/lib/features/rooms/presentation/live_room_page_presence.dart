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
    if (!_viewerCanManageRoom) return;

    _hostSeatOneTimer?.cancel();
    _hostSeatOneRetryTimer?.cancel();

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

    // Do not keep forcing seat 1 if the host/admin is already seated anywhere.
    // The media server accepts seat 1 correctly, but repeated auto-seat retries
    // were causing repeated takeSeat/setSelfMuted/produce calls and made the UI
    // look like seat 1 was failing.
    if (_seatController.currentUserIsSeated) {
      _hostSeatOneTimer?.cancel();
      _hostSeatOneRetryTimer?.cancel();
      return;
    }

    final firstSeat = _seatController.seats.first;
    if (firstSeat.locked) return;

    final firstSeatUser = firstSeat.user;
    if (firstSeatUser != null) {
      // If the first seat is already held by someone else, do not steal it or
      // spam the media server. Admins can switch manually.
      return;
    }

    _seatController.occupySeat(0);
  }
}
