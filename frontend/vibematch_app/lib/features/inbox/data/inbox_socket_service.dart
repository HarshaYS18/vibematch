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
    sendRaw(const <String, dynamic>{'type': 'ping'});
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
      'type': 'inbox.chat_activity',
      'conversation_id': conversationId,
      'activity': activity,
      'command_id': _commandId('activity'),
    });

    if (activity == 'typing') {
      sendRaw(<String, dynamic>{
        'type': 'inbox.typing_start',
        'conversation_id': conversationId,
        'command_id': _commandId('typing-start'),
      });
    } else if (activity == 'idle') {
      sendRaw(<String, dynamic>{
        'type': 'inbox.typing_stop',
        'conversation_id': conversationId,
        'command_id': _commandId('typing-stop'),
      });
    }
  }

  void markRead(String conversationId) {
    sendRaw(<String, dynamic>{
      'type': 'inbox.mark_read',
      'conversation_id': conversationId,
      'command_id': _commandId('mark-read'),
    });
  }

  void sendRaw(Map<String, dynamic> payload) {
    _hub.sendRaw(payload);
  }

  String _commandId(String kind) =>
      'inbox-$kind-${DateTime.now().microsecondsSinceEpoch}';

  void disconnect() {
    final subscription = _subscription;
    _subscription = null;
    _onEvent = null;
    unawaited(subscription?.cancel());
  }
}
