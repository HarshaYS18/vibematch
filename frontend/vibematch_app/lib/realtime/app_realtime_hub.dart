import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/vm_api_config.dart';
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
    this.expectedSequence,
    this.observedSequence,
  });

  final RealtimeResyncReason reason;
  final String stream;
  final int? expectedSequence;
  final int? observedSequence;
}

class AppRealtimeHub {
  AppRealtimeHub._();

  static final AppRealtimeHub shared = AppRealtimeHub._();

  final StreamController<RealtimeEventEnvelope> _eventController =
      StreamController<RealtimeEventEnvelope>.broadcast();
  final StreamController<RealtimeResyncRequest> _resyncController =
      StreamController<RealtimeResyncRequest>.broadcast();

  RealtimeClient? _client;
  StreamSubscription<RealtimeEventEnvelope>? _eventSubscription;
  StreamSubscription<RealtimeGap>? _gapSubscription;
  StreamSubscription<int>? _reconnectSubscription;

  Stream<RealtimeEventEnvelope> get events => _eventController.stream;
  Stream<RealtimeResyncRequest> get resyncRequests => _resyncController.stream;
  bool get isConnected => _client?.isConnected ?? false;

  void configure(RealtimeClient client) {
    if (identical(_client, client)) return;

    unawaited(_eventSubscription?.cancel());
    unawaited(_gapSubscription?.cancel());
    unawaited(_reconnectSubscription?.cancel());
    if (_client != null) {
      unawaited(_client!.dispose());
    }

    _client = client;
    _eventSubscription = client.events.listen(_eventController.add);
    _gapSubscription = client.gaps.listen((gap) {
      _resyncController.add(
        RealtimeResyncRequest(
          reason: RealtimeResyncReason.sequenceGap,
          stream: gap.stream,
          expectedSequence: gap.expectedSequence,
          observedSequence: gap.observedSequence,
        ),
      );
    });
    _reconnectSubscription = client.reconnects.listen((_) {
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
  }

  void sendRaw(Map<String, dynamic> payload) {
    _client?.sendRaw(payload);
  }

  void markResynced(String stream, int sequence) {
    _client?.markResynced(stream, sequence);
  }

  Future<void> stop() async {
    await _client?.stop();
  }
}

final appRealtimeHubProvider = Provider.autoDispose<AppRealtimeHub>((ref) {
  final hub = AppRealtimeHub.shared;
  final sessions = ref.read(sessionRepositoryProvider.notifier);

  final client = RealtimeClient(
    tokenProvider: () => ref.read(sessionRepositoryProvider).accessToken,
    socketUriBuilder: (token) {
      final base = VmApiConfig.baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      return Uri.parse(
        '$base/ws/inbox?token=${Uri.encodeQueryComponent(token)}',
      );
    },
  );
  hub.configure(client);

  final invalidationSubscription = hub.events.listen((event) {
    if (event.type == 'session_replaced') {
      unawaited(sessions.logout());
    }
  });

  ref.onDispose(() {
    unawaited(invalidationSubscription.cancel());
    unawaited(hub.stop());
  });
  return hub;
});
