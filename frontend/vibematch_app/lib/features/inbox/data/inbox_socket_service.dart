import 'dart:async';

import '../../../realtime/app_realtime_hub.dart';

class InboxSocketService {
  InboxSocketService({AppRealtimeHub? hub})
      : _hub = hub ?? AppRealtimeHub.shared;

  final AppRealtimeHub _hub;
  StreamSubscription<dynamic>? _subscription;
  void Function(Map<String, dynamic> event)? _onEvent;

  bool get isConnected => _hub.isConnected;

  Future<void> connect({
    required void Function(Map<String, dynamic> event) onEvent,
  }) async {
    _onEvent = onEvent;
    _subscription ??= _hub.events.listen((event) {
      _onEvent?.call(event.toLegacyEvent());
    });

    await _hub.start();
    sendRaw(const <String, dynamic>{'event': 'ping'});
  }

  void sendTypingStart(String conversationId) {
    sendChatActivity(conversationId: conversationId, activity: 'typing');
  }

  void sendTypingStop(String conversationId) {
    sendChatActivity(conversationId: conversationId, activity: 'idle');
  }

  void sendChatActivity({
    required String conversationId,
    required String activity,
  }) {
    sendRaw(<String, dynamic>{
      'event': 'chat_activity',
      'conversation_id': conversationId,
      'activity': activity,
    });

    if (activity == 'typing') {
      sendRaw(<String, dynamic>{
        'event': 'typing_start',
        'conversation_id': conversationId,
      });
    } else if (activity == 'idle') {
      sendRaw(<String, dynamic>{
        'event': 'typing_stop',
        'conversation_id': conversationId,
      });
    }
  }

  void markRead(String conversationId) {
    sendRaw(<String, dynamic>{
      'event': 'mark_read',
      'conversation_id': conversationId,
    });
  }

  void sendRaw(Map<String, dynamic> payload) {
    _hub.sendRaw(payload);
  }

  void disconnect() {
    final subscription = _subscription;
    _subscription = null;
    _onEvent = null;
    unawaited(subscription?.cancel());
  }
}
