enum OttJavascriptEventType {
  playerReady,
  playerState,
  position,
  buffering,
  seekableRange,
  playbackError,
  drmError,
  loginRequired,
  contentChanged,
}

class OttJavascriptEvent {
  const OttJavascriptEvent({
    required this.type,
    required this.provider,
    required this.state,
    required this.positionMs,
    required this.durationMs,
    required this.playbackRate,
    required this.live,
    required this.seekableStartMs,
    required this.liveEdgeMs,
    required this.error,
  });

  final OttJavascriptEventType type;
  final String provider;
  final String? state;
  final int? positionMs;
  final int? durationMs;
  final double? playbackRate;
  final bool live;
  final int? seekableStartMs;
  final int? liveEdgeMs;
  final String? error;
}

class OttJavascriptBridge {
  const OttJavascriptBridge._();

  static const String handlerName = 'funkeyOttBridge';

  static OttJavascriptEvent? tryParse(dynamic raw) {
    dynamic value = raw;
    if (value is List && value.isNotEmpty) value = value.first;
    if (value is! Map) return null;

    final map = value.map<String, dynamic>(
      (key, item) => MapEntry(key.toString(), item),
    );
    final type = _eventType(map['type']?.toString());
    final provider = map['provider']?.toString().trim() ?? '';
    if (type == null || provider.isEmpty) return null;

    int? integer(dynamic item) {
      if (item is int) return item;
      if (item is num) return item.round();
      return int.tryParse(item?.toString() ?? '');
    }

    double? decimal(dynamic item) {
      if (item is num) return item.toDouble();
      return double.tryParse(item?.toString() ?? '');
    }

    return OttJavascriptEvent(
      type: type,
      provider: provider,
      state: map['state']?.toString(),
      positionMs: integer(map['positionMs']),
      durationMs: integer(map['durationMs']),
      playbackRate: decimal(map['playbackRate']),
      live: map['live'] == true,
      seekableStartMs: integer(map['seekableStartMs']),
      liveEdgeMs: integer(map['liveEdgeMs']),
      error: map['error']?.toString(),
    );
  }

  static OttJavascriptEventType? _eventType(String? raw) {
    switch (raw?.trim().toUpperCase()) {
      case 'PLAYER_READY':
        return OttJavascriptEventType.playerReady;
      case 'PLAYER_STATE':
        return OttJavascriptEventType.playerState;
      case 'POSITION':
        return OttJavascriptEventType.position;
      case 'BUFFERING':
        return OttJavascriptEventType.buffering;
      case 'SEEKABLE_RANGE':
        return OttJavascriptEventType.seekableRange;
      case 'PLAYBACK_ERROR':
        return OttJavascriptEventType.playbackError;
      case 'DRM_ERROR':
        return OttJavascriptEventType.drmError;
      case 'LOGIN_REQUIRED':
        return OttJavascriptEventType.loginRequired;
      case 'CONTENT_CHANGED':
        return OttJavascriptEventType.contentChanged;
    }
    return null;
  }
}
