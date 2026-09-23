class RoomSeatLayoutSyncService {
  const RoomSeatLayoutSyncService._();

  /// Compatibility hook retained for legacy callers.
  ///
  /// Seat layout is persisted through RoomSettingsRepository. The backend
  /// mutation publishes the authoritative room delta onto the single Go
  /// application WebSocket, so a second best-effort socket broadcast would
  /// duplicate the mutation/event and is intentionally unnecessary.
  static Future<void> broadcastSeatLayout({
    required String roomId,
    required String seatLayoutId,
  }) async {
    if (roomId.trim().isEmpty || seatLayoutId.trim().isEmpty) return;
  }
}
