class RoomAudioState {
  const RoomAudioState({
    this.connected = false,
    this.engineLoaded = false,
    this.publishing = false,
    this.selfMuted = false,
    this.mySeatNo,
    this.remoteConsumerCount = 0,
    this.status = 'Audio idle',
  });

  final bool connected;
  final bool engineLoaded;
  final bool publishing;
  final bool selfMuted;
  final int? mySeatNo;
  final int remoteConsumerCount;
  final String status;

  RoomAudioState copyWith({
    bool? connected,
    bool? engineLoaded,
    bool? publishing,
    bool? selfMuted,
    int? mySeatNo,
    bool clearMySeatNo = false,
    int? remoteConsumerCount,
    String? status,
  }) {
    return RoomAudioState(
      connected: connected ?? this.connected,
      engineLoaded: engineLoaded ?? this.engineLoaded,
      publishing: publishing ?? this.publishing,
      selfMuted: selfMuted ?? this.selfMuted,
      mySeatNo: clearMySeatNo ? null : mySeatNo ?? this.mySeatNo,
      remoteConsumerCount: remoteConsumerCount ?? this.remoteConsumerCount,
      status: status ?? this.status,
    );
  }
}
