import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class InboxSocketService {
  InboxSocketService({AuthApiService authApiService = const AuthApiService()})
      : _authApiService = authApiService;

  final AuthApiService _authApiService;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _connecting = false;

  bool get isConnected => _channel != null;

  Future<void> connect({required void Function(Map<String, dynamic> event) onEvent}) async {
    if (_connecting || _channel != null) return;

    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) return;

    _connecting = true;
    try {
      final uri = Uri.parse(_socketUrl(token));
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      _subscription = channel.stream.listen(
        (raw) {
          if (raw is! String) return;
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            if (decoded['event'] == 'session_replaced') {
              unawaited(_authApiService.logout());
              disconnect();
              return;
            }
            onEvent(decoded);
          }
        },
        onDone: disconnect,
        onError: (_) => disconnect(),
        cancelOnError: true,
      );

      sendRaw({'event': 'ping'});
    } catch (_) {
      disconnect();
    } finally {
      _connecting = false;
    }
  }

  void sendTypingStart(String conversationId) {
    sendRaw({'event': 'typing_start', 'conversation_id': conversationId});
  }

  void sendTypingStop(String conversationId) {
    sendRaw({'event': 'typing_stop', 'conversation_id': conversationId});
  }

  void markRead(String conversationId) {
    sendRaw({'event': 'mark_read', 'conversation_id': conversationId});
  }

  void sendRaw(Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode(payload));
    } catch (_) {
      disconnect();
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _connecting = false;
  }

  String _socketUrl(String token) {
    final base = VmApiConfig.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$base/ws/inbox?token=${Uri.encodeComponent(token)}';
  }
}
