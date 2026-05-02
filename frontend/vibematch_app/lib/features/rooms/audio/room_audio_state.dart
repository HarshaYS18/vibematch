class RoomAudioState {
  const RoomAudioState({
    this.connected = false,
    this.connecting = false,
    this.reconnecting = false,
    this.engineLoaded = false,
    this.publishing = false,
    this.selfMuted = false,
    this.mySeatNo,
    this.remoteConsumerCount = 0,
    this.lastError,
    this.status = 'Audio idle',
  });

  final bool connected;
  final bool connecting;
  final bool reconnecting;
  final bool engineLoaded;
  final bool publishing;
  final bool selfMuted;
  final int? mySeatNo;
  final int remoteConsumerCount;
  final String? lastError;
  final String status;

  bool get hasProblem => lastError != null && lastError!.isNotEmpty;

  RoomAudioState copyWith({
    bool? connected,
    bool? connecting,
    bool? reconnecting,
    bool? engineLoaded,
    bool? publishing,
    bool? selfMuted,
    int? mySeatNo,
    bool clearMySeatNo = false,
    int? remoteConsumerCount,
    String? lastError,
    bool clearLastError = false,
    String? status,
  }) {
    return RoomAudioState(
      connected: connected ?? this.connected,
      connecting: connecting ?? this.connecting,
      reconnecting: reconnecting ?? this.reconnecting,
      engineLoaded: engineLoaded ?? this.engineLoaded,
      publishing: publishing ?? this.publishing,
      selfMuted: selfMuted ?? this.selfMuted,
      mySeatNo: clearMySeatNo ? null : mySeatNo ?? this.mySeatNo,
      remoteConsumerCount: remoteConsumerCount ?? this.remoteConsumerCount,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      status: status ?? this.status,
    );
  }
}
