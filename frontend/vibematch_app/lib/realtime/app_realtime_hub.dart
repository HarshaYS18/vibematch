import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/vm_api_config.dart';
import '../foundation/di/app_dependencies.dart';
import '../foundation/realtime/realtime_capability_service.dart';
import '../foundation/realtime/realtime_client.dart';
import '../foundation/realtime/realtime_event_envelope.dart';
import '../session/data/session_repository.dart';

enum RealtimeResyncReason {
  reconnect,
  sequenceGap,
}

class RealtimeResyncRequest {
  const RealtimeResyncRequest({
    required this.reason,
    required this.stream,
    this.roomId,
    this.expectedSequence,
    this.observedSequence,
  });

  final RealtimeResyncReason reason;
  final String stream;
  final String? roomId;
  final int? expectedSequence;
  final int? observedSequence;
}

class _RoomSubscriptionCursor {
  _RoomSubscriptionCursor({
    this.stream,
    this.lastSequence = 0,
  });

  String? stream;
  int lastSequence;
  RealtimeCapabilityGrant? capability;
  bool capabilityPending = false;
}

typedef RoomCapabilityProvider = Future<RealtimeCapabilityGrant> Function(
  String roomId,
);

class AppRealtimeHub {
  AppRealtimeHub._();

  static final AppRealtimeHub shared = AppRealtimeHub._();

  final StreamController<RealtimeEventEnvelope> _eventController =
      StreamController<RealtimeEventEnvelope>.broadcast();
  final StreamController<RealtimeResyncRequest> _resyncController =
      StreamController<RealtimeResyncRequest>.broadcast();
  final Map<String, _RoomSubscriptionCursor> _roomSubscriptions =
      <String, _RoomSubscriptionCursor>{};

  RealtimeClient? _client;
  RoomCapabilityProvider? _roomCapabilityProvider;
  StreamSubscription<RealtimeEventEnvelope>? _eventSubscription;
  StreamSubscription<RealtimeGap>? _gapSubscription;
  StreamSubscription<int>? _reconnectSubscription;

  Stream<RealtimeEventEnvelope> get events => _eventController.stream;
  Stream<RealtimeResyncRequest> get resyncRequests => _resyncController.stream;
  bool get isConnected => _client?.isConnected ?? false;

  void configure(
    RealtimeClient client, {
    required RoomCapabilityProvider roomCapabilityProvider,
  }) {
    if (identical(_client, client)) return;

    unawaited(_eventSubscription?.cancel());
    unawaited(_gapSubscription?.cancel());
    unawaited(_reconnectSubscription?.cancel());
    if (_client != null) {
      unawaited(_client!.dispose());
    }

    _client = client;
    _roomCapabilityProvider = roomCapabilityProvider;
    _eventSubscription = client.events.listen(_handleEvent);
    _gapSubscription = client.gaps.listen(_handleGap);
    _reconnectSubscription = client.reconnects.listen((_) {
      for (final roomId in _roomSubscriptions.keys) {
        _sendRoomSubscription(roomId);
      }
      _resyncController.add(
        const RealtimeResyncRequest(
          reason: RealtimeResyncReason.reconnect,
          stream: '*',
        ),
      );
    });
  }

  Future<void> start() async {
    await _client?.connect();
    if (isConnected) {
      for (final roomId in _roomSubscriptions.keys) {
        _sendRoomSubscription(roomId);
      }
    }
  }

  void subscribeRoom(
    String roomId, {
    String? stream,
    int lastSequence = 0,
  }) {
    final normalized = roomId.trim();
    if (normalized.isEmpty) return;
    final cursor = _roomSubscriptions.putIfAbsent(
      normalized,
      () => _RoomSubscriptionCursor(),
    );
    if (stream != null && stream.trim().isNotEmpty) {
      cursor.stream = stream.trim();
      cursor.lastSequence = lastSequence > 0 ? lastSequence : 0;
    }
    if (isConnected) {
      _sendRoomSubscription(normalized);
    }
  }

  void unsubscribeRoom(String roomId) {
    final normalized = roomId.trim();
    if (normalized.isEmpty) return;
    _roomSubscriptions.remove(normalized);
    sendRaw(<String, dynamic>{
      'type': 'unsubscribe',
      'room_public_id': normalized,
    });
  }

  void _sendRoomSubscription(String roomId) {
    final cursor = _roomSubscriptions[roomId];
    if (cursor == null || cursor.capabilityPending) return;
    unawaited(_sendRoomSubscriptionWithCapability(roomId, cursor));
  }

  Future<void> _sendRoomSubscriptionWithCapability(
    String roomId,
    _RoomSubscriptionCursor cursor,
  ) async {
    if (!isConnected || _roomSubscriptions[roomId] != cursor) return;
    var grant = cursor.capability;
    if (grant == null || !grant.isFresh) {
      final provider = _roomCapabilityProvider;
      if (provider == null) return;
      cursor.capabilityPending = true;
      try {
        grant = await provider(roomId);
        if (_roomSubscriptions[roomId] != cursor) return;
        cursor.capability = grant;
      } catch (_) {
        return;
      } finally {
        cursor.capabilityPending = false;
      }
    }
    if (!isConnected || _roomSubscriptions[roomId] != cursor) {
      return;
    }
    final payload = <String, dynamic>{
      'type': 'subscribe',
      'room_public_id': roomId,
      'capability': grant.token,
    };
    final stream = cursor.stream;
    if (stream != null && stream.isNotEmpty) {
      payload['stream'] = stream;
      payload['last_sequence'] = cursor.lastSequence;
    }
    sendRaw(payload);
  }

  void _handleEvent(RealtimeEventEnvelope event) {
    _rememberRoomCursor(event);

    if (event.type == 'room.permission_revoked' ||
        event.type == 'subscription_revoked') {
      final roomId =
          event.payload['room_public_id']?.toString().trim() ??
          event.raw['room_public_id']?.toString().trim();
      final cursor = roomId == null ? null : _roomSubscriptions[roomId];
      if (cursor != null) {
        cursor.capability = null;
        if (isConnected) {
          _sendRoomSubscription(roomId!);
        }
      }
    }

    if (event.type == 'subscribed' &&
        _bool(event.payload['resync_required'])) {
      final roomId = event.payload['room_public_id']?.toString().trim();
      final cursor = roomId == null ? null : _roomSubscriptions[roomId];
      _resyncController.add(
        RealtimeResyncRequest(
          reason: RealtimeResyncReason.sequenceGap,
          stream: cursor?.stream ?? event.payload['stream']?.toString() ?? '',
          roomId: roomId,
          expectedSequence: cursor == null ? null : cursor.lastSequence + 1,
          observedSequence: _int(event.payload['current_sequence']),
        ),
      );
    }

    _eventController.add(event);
  }

  void _handleGap(RealtimeGap gap) {
    final roomId = _roomIdFromStream(gap.stream);
    if (roomId != null && _roomSubscriptions.containsKey(roomId)) {
      final cursor = _roomSubscriptions[roomId]!;
      cursor.stream = gap.stream;
      cursor.lastSequence = gap.expectedSequence - 1;
      _sendRoomSubscription(roomId);
      return;
    }

    _resyncController.add(
      RealtimeResyncRequest(
        reason: RealtimeResyncReason.sequenceGap,
        stream: gap.stream,
        expectedSequence: gap.expectedSequence,
        observedSequence: gap.observedSequence,
      ),
    );
  }

  void _rememberRoomCursor(RealtimeEventEnvelope event) {
    if (!event.isSequenced) return;
    final roomId = _roomIdFromStream(event.stream);
    if (roomId == null) return;
    final cursor = _roomSubscriptions[roomId];
    if (cursor == null) return;
    cursor.stream = event.stream;
    if (event.sequence > cursor.lastSequence) {
      cursor.lastSequence = event.sequence;
    }
  }

  void sendRaw(Map<String, dynamic> payload) {
    _client?.sendRaw(payload);
  }

  void markResynced(String stream, int sequence) {
    _client?.markResynced(stream, sequence);
    final roomId = _roomIdFromStream(stream);
    if (roomId == null) return;
    final cursor = _roomSubscriptions[roomId];
    if (cursor == null) return;
    cursor.stream = stream;
    if (sequence > cursor.lastSequence) {
      cursor.lastSequence = sequence;
    }
  }

  Future<void> stop() async {
    await _client?.stop();
  }

  String? _roomIdFromStream(String stream) {
    if (!stream.startsWith('room:')) return null;
    final parts = stream.split(':');
    if (parts.length < 3 || parts[1].trim().isEmpty) return null;
    return parts[1];
  }
}

final appRealtimeHubProvider = Provider.autoDispose<AppRealtimeHub>((ref) {
  final hub = AppRealtimeHub.shared;
  final sessions = ref.read(sessionRepositoryProvider.notifier);
  final capabilityService = RealtimeCapabilityService(
    networkClient: ref.read(appNetworkClientProvider),
    accessTokenProvider: () => ref.read(sessionRepositoryProvider).accessToken,
  );

  final client = RealtimeClient(
    tokenProvider: () => ref.read(sessionRepositoryProvider).accessToken,
    capabilityTokenProvider: () async =>
        (await capabilityService.issue()).token,
    socketUriBuilder: (_) => Uri.parse(VmApiConfig.realtimeWebSocketUrl),
  );
  hub.configure(
    client,
    roomCapabilityProvider: (roomId) =>
        capabilityService.issue(roomId: roomId),
  );

  final invalidationSubscription = hub.events.listen((event) {
    if (event.type == 'session_replaced' ||
        event.type == 'auth.session_revoked') {
      unawaited(sessions.logout());
    }
  });

  ref.onDispose(() {
    unawaited(invalidationSubscription.cancel());
    unawaited(hub.stop());
  });
  return hub;
});

bool _bool(dynamic value) {
  if (value is bool) return value;
  final text = value?.toString().trim().toLowerCase();
  return text == 'true' || text == '1';
}


int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
