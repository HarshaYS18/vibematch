class ActiveRoomContext {
  const ActiveRoomContext._();

  static String? _roomPublicId;
  static String? _roomName;

  static String? get roomPublicId => _roomPublicId;
  static String? get roomName => _roomName;

  static void setActiveRoom({required String roomPublicId, required String roomName}) {
    final cleanRoomPublicId = roomPublicId.trim();
    final cleanRoomName = roomName.trim();
    if (cleanRoomPublicId.isEmpty) return;
    _roomPublicId = cleanRoomPublicId;
    _roomName = cleanRoomName.isEmpty ? 'Live Room' : cleanRoomName;
  }

  static void clearIfMatches(String roomPublicId) {
    if (_roomPublicId == roomPublicId.trim()) {
      _roomPublicId = null;
      _roomName = null;
    }
  }
}
