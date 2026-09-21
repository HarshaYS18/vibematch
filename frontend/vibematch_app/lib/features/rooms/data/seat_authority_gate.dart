/// Keeps local media intent behind the room control plane's seat snapshots.
///
/// A seat command is asynchronous.  In particular, an older snapshot can
/// arrive between sending `seat/take` and FastAPI applying it.  Treating that
/// snapshot as a revocation causes the mic start/stop recovery loop this class
/// prevents.
class SeatAuthorityGate {
  int? _pendingSeatIndex;
  bool? _pendingMicEnabled;

  int? get pendingSeatIndex => _pendingSeatIndex;

  void requestSeat(int seatIndex, {bool? micEnabled}) {
    _pendingSeatIndex = seatIndex;
    if (micEnabled != null) _pendingMicEnabled = micEnabled;
  }

  void requestMicEnabled(bool enabled) {
    _pendingMicEnabled = enabled;
  }

  void cancelPendingSeat() {
    _pendingSeatIndex = null;
    _pendingMicEnabled = null;
  }

  void rejectSeatRequest() => cancelPendingSeat();

  SeatAuthorityDecision observe({
    required int? authoritativeSeatIndex,
    required bool authoritativeMicEnabled,
    required bool adminMuted,
  }) {
    if (authoritativeSeatIndex == null) {
      // An old snapshot is not a revocation while our command is outstanding.
      return SeatAuthorityDecision(
        awaitSeatConfirmation: _pendingSeatIndex != null,
        shouldLeaveSeat: _pendingSeatIndex == null,
      );
    }

    _pendingSeatIndex = null;
    if (_pendingMicEnabled == authoritativeMicEnabled) {
      _pendingMicEnabled = null;
    }

    return SeatAuthorityDecision(
      confirmedSeatIndex: authoritativeSeatIndex,
      micEnabled: authoritativeMicEnabled && !adminMuted,
    );
  }
}

class SeatAuthorityDecision {
  const SeatAuthorityDecision({
    this.confirmedSeatIndex,
    this.micEnabled,
    this.awaitSeatConfirmation = false,
    this.shouldLeaveSeat = false,
  });

  final int? confirmedSeatIndex;
  final bool? micEnabled;
  final bool awaitSeatConfirmation;
  final bool shouldLeaveSeat;
}
