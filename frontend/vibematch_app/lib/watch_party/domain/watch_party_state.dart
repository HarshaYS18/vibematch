import '../../room_session/domain/room_session_state.dart';

enum WatchPlaybackState {
  paused,
  playing,
}

enum WatchTimelineMode {
  vod,
  live,
}

const int defaultWatchTargetLiveLatencyMs = 10000;

class WatchSession {
  const WatchSession({
    required this.active,
    required this.sessionId,
    required this.roomId,
    required this.provider,
    required this.contentId,
    required this.contentUrl,
    required this.contentTitle,
    required this.hostUserId,
    required this.controllerUserId,
    required this.playbackState,
    required this.positionMs,
    required this.serverAnchorTimeMs,
    required this.playbackRate,
    required this.revision,
    required this.eventSequence,
    this.timelineMode = WatchTimelineMode.vod,
    this.targetLiveLatencyMs = defaultWatchTargetLiveLatencyMs,
  });

  final bool active;
  final String sessionId;
  final String roomId;
  final String provider;
  final String? contentId;
  final String? contentUrl;
  final String? contentTitle;
  final int hostUserId;
  final int controllerUserId;
  final WatchPlaybackState playbackState;
  final int positionMs;

  /// Authoritative server epoch in milliseconds at which [positionMs] was
  /// anchored. Client device clocks are never treated as authoritative.
  final int serverAnchorTimeMs;
  final double playbackRate;
  final int revision;
  final int eventSequence;
  final WatchTimelineMode timelineMode;
  final int targetLiveLatencyMs;

  bool get isLive => timelineMode == WatchTimelineMode.live;

  int targetPositionMsAt(int serverTimeMs) {
    if (!active || playbackState != WatchPlaybackState.playing) {
      return positionMs;
    }
    final elapsedMs =
        (serverTimeMs - serverAnchorTimeMs).clamp(0, 1 << 62).toInt();
    return positionMs + (elapsedMs * playbackRate).round();
  }

  static WatchSession? tryFromJson(Map<String, dynamic> json) {
    final sessionId = _text(json['session_id']);
    if (sessionId == null) return null;

    return WatchSession(
      active: _bool(json['active'], fallback: false),
      sessionId: sessionId,
      roomId: _text(json['room_id']) ?? '',
      provider: _text(json['provider']) ?? '',
      contentId: _text(json['content_id']),
      contentUrl: _text(json['content_url']),
      contentTitle: _text(json['content_title']),
      hostUserId: _int(json['host_user_id']),
      controllerUserId: _int(json['controller_user_id']),
      playbackState: _playbackState(json['playback_state']),
      positionMs: _int(json['position_ms']).clamp(0, 1 << 62).toInt(),
      serverAnchorTimeMs: _int(json['server_anchor_time']),
      playbackRate: _double(json['playback_rate'], fallback: 1),
      revision: _int(json['revision']),
      eventSequence: _int(json['event_sequence']),
      timelineMode: _timelineMode(json['timeline_mode']),
      targetLiveLatencyMs: _positiveInt(
        json['target_live_latency_ms'],
        fallback: defaultWatchTargetLiveLatencyMs,
      ),
    );
  }
}

class WatchPartyState {
  const WatchPartyState({
    required this.roomId,
    required this.session,
    required this.serverTimeMs,
    required this.errorMessage,
  });

  factory WatchPartyState.initial(String roomId) {
    return WatchPartyState(
      roomId: roomId,
      session: null,
      serverTimeMs: 0,
      errorMessage: null,
    );
  }

  factory WatchPartyState.fromRoomState(RoomSessionState roomState) {
    return WatchPartyState(
      roomId: roomState.roomId,
      session: WatchSession.tryFromJson(roomState.watchParty),
      serverTimeMs: _int(roomState.room['server_time']),
      errorMessage: null,
    );
  }

  final String roomId;
  final WatchSession? session;
  final int serverTimeMs;
  final String? errorMessage;

  bool get active => session?.active == true;

  WatchPartyState copyWith({
    WatchSession? session,
    bool clearSession = false,
    int? serverTimeMs,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WatchPartyState(
      roomId: roomId,
      session: clearSession ? null : session ?? this.session,
      serverTimeMs: serverTimeMs ?? this.serverTimeMs,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

WatchPlaybackState _playbackState(dynamic value) {
  return value?.toString().trim().toLowerCase() == 'playing'
      ? WatchPlaybackState.playing
      : WatchPlaybackState.paused;
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _double(dynamic value, {required double fallback}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _bool(dynamic value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1') return true;
  if (normalized == 'false' || normalized == '0') return false;
  return fallback;
}

WatchTimelineMode _timelineMode(dynamic value) {
  return value?.toString().trim().toLowerCase() == 'live'
      ? WatchTimelineMode.live
      : WatchTimelineMode.vod;
}

int _positiveInt(dynamic value, {required int fallback}) {
  final parsed = _int(value);
  return parsed > 0 ? parsed : fallback;
}

