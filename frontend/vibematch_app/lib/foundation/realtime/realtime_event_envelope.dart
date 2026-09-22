enum RealtimeSequenceDecision {
  accepted,
  duplicate,
  gap,
}

class RealtimeEventEnvelope {
  const RealtimeEventEnvelope({
    required this.eventId,
    required this.sequence,
    required this.stream,
    required this.type,
    required this.serverTime,
    required this.payload,
    required this.raw,
  });

  final String eventId;
  final int sequence;
  final String stream;
  final String type;
  final DateTime? serverTime;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> raw;

  bool get isSequenced => sequence > 0 && stream.trim().isNotEmpty;

  factory RealtimeEventEnvelope.fromJson(
    Map<String, dynamic> json, {
    String fallbackStream = 'app:legacy',
  }) {
    final rawPayload = json['payload'];
    final payload = rawPayload is Map
        ? rawPayload.cast<String, dynamic>()
        : Map<String, dynamic>.from(json);
    final type = _text(json['type']) ?? _text(json['event']) ?? 'app.event';
    final sequence = _int(json['sequence']);
    final stream = _text(json['stream']) ?? fallbackStream;
    final eventId =
        _text(json['eventId']) ??
        _text(json['event_id']) ??
        'legacy:$stream:$sequence:$type';
    final serverTimeText =
        _text(json['serverTime']) ?? _text(json['server_time']);

    return RealtimeEventEnvelope(
      eventId: eventId,
      sequence: sequence,
      stream: stream,
      type: type,
      serverTime: serverTimeText == null
          ? null
          : DateTime.tryParse(serverTimeText)?.toUtc(),
      payload: Map<String, dynamic>.unmodifiable(payload),
      raw: Map<String, dynamic>.unmodifiable(json),
    );
  }

  Map<String, dynamic> toLegacyEvent() {
    final legacy = Map<String, dynamic>.from(raw);
    legacy.putIfAbsent('event', () => type);
    return legacy;
  }
}

class RealtimeGap {
  const RealtimeGap({
    required this.stream,
    required this.expectedSequence,
    required this.observedSequence,
    required this.event,
  });

  final String stream;
  final int expectedSequence;
  final int observedSequence;
  final RealtimeEventEnvelope event;
}

class RealtimeStreamCursor {
  final Map<String, int> _lastSequenceByStream = <String, int>{};

  int? lastSequence(String stream) => _lastSequenceByStream[stream];

  RealtimeSequenceDecision accept(RealtimeEventEnvelope event) {
    if (!event.isSequenced) return RealtimeSequenceDecision.accepted;

    final last = _lastSequenceByStream[event.stream];
    if (last == null) {
      _lastSequenceByStream[event.stream] = event.sequence;
      return RealtimeSequenceDecision.accepted;
    }
    if (event.sequence <= last) {
      return RealtimeSequenceDecision.duplicate;
    }
    if (event.sequence == last + 1) {
      _lastSequenceByStream[event.stream] = event.sequence;
      return RealtimeSequenceDecision.accepted;
    }
    return RealtimeSequenceDecision.gap;
  }

  RealtimeGap gapFor(RealtimeEventEnvelope event) {
    final last = _lastSequenceByStream[event.stream] ?? 0;
    return RealtimeGap(
      stream: event.stream,
      expectedSequence: last + 1,
      observedSequence: event.sequence,
      event: event,
    );
  }

  void markResynced(String stream, int sequence) {
    if (sequence <= 0) return;
    final current = _lastSequenceByStream[stream] ?? 0;
    if (sequence > current) {
      _lastSequenceByStream[stream] = sequence;
    }
  }

  void clear() => _lastSequenceByStream.clear();
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
