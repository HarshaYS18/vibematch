enum InboxCallType {
  audio,
  video,
}

enum InboxCallDirection {
  incoming,
  outgoing,
}

enum InboxCallStatus {
  ringing,
  accepted,
  declined,
  missed,
  ended,
  failed,
}

class InboxCallSession {
  const InboxCallSession({
    required this.id,
    required this.conversationId,
    required this.peerName,
    required this.peerAvatarText,
    required this.type,
    required this.direction,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.duration,
    this.peerAvatarUrl,
    this.roomId,
  });

  final String id;
  final String conversationId;
  final String peerName;
  final String peerAvatarText;
  final String? peerAvatarUrl;
  final InboxCallType type;
  final InboxCallDirection direction;
  final InboxCallStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration? duration;
  final String? roomId;

  bool get isVideo => type == InboxCallType.video;
  bool get isIncoming => direction == InboxCallDirection.incoming;
  bool get isOutgoing => direction == InboxCallDirection.outgoing;
  bool get isRinging => status == InboxCallStatus.ringing;
  bool get isConnected => status == InboxCallStatus.accepted;
  bool get isMissed => status == InboxCallStatus.missed;
  bool get isTerminal => status == InboxCallStatus.declined || status == InboxCallStatus.missed || status == InboxCallStatus.ended || status == InboxCallStatus.failed;

  String get title {
    if (isIncoming && isRinging) return isVideo ? 'Incoming video call' : 'Incoming voice call';
    if (isOutgoing && isRinging) return isVideo ? 'Calling video...' : 'Calling...';
    return isVideo ? 'Video call' : 'Voice call';
  }

  String get iconLabel => isVideo ? 'Video' : 'Voice';

  String get statusLabel {
    return switch (status) {
      InboxCallStatus.ringing => isIncoming ? 'Ringing now' : 'Waiting for answer',
      InboxCallStatus.accepted => 'Connected',
      InboxCallStatus.declined => 'Declined',
      InboxCallStatus.missed => 'Missed call',
      InboxCallStatus.ended => duration == null ? 'Call ended' : 'Call ended • ${_formatDuration(duration!)}',
      InboxCallStatus.failed => 'Call failed',
    };
  }

  InboxCallSession copyWith({
    InboxCallStatus? status,
    DateTime? endedAt,
    Duration? duration,
    String? roomId,
  }) {
    return InboxCallSession(
      id: id,
      conversationId: conversationId,
      peerName: peerName,
      peerAvatarText: peerAvatarText,
      peerAvatarUrl: peerAvatarUrl,
      type: type,
      direction: direction,
      status: status ?? this.status,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      roomId: roomId ?? this.roomId,
    );
  }

  static String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds.clamp(0, 24 * 60 * 60);
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    if (minutes < 60) return '$minutes:${remainder.toString().padLeft(2, '0')}';
    final hours = minutes ~/ 60;
    final minuteRemainder = minutes % 60;
    return '$hours:${minuteRemainder.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }
}

class InboxCallSummaryMessage {
  const InboxCallSummaryMessage({
    required this.callId,
    required this.conversationId,
    required this.type,
    required this.direction,
    required this.status,
    required this.label,
    required this.createdAt,
    this.duration,
  });

  final String callId;
  final String conversationId;
  final InboxCallType type;
  final InboxCallDirection direction;
  final InboxCallStatus status;
  final String label;
  final DateTime createdAt;
  final Duration? duration;

  bool get isIncoming => direction == InboxCallDirection.incoming;
  bool get isVideo => type == InboxCallType.video;

  Map<String, Object?> toMetadataJson() {
    return <String, Object?>{
      'call_id': callId,
      'call_type': type.name,
      'direction': direction.name,
      'status': status.name,
      'label': label,
      'duration_seconds': duration?.inSeconds,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
