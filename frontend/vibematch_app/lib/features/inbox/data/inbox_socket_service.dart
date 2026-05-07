import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class InboxSocketService {
  InboxSocketService({AuthApiService authApiService = const AuthApiService()})
      : _authApiService = authApiService;

  final AuthApiService _authApiService;
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  bool _connecting = false;

  bool get isConnected => _socket != null;

  Future<void> connect({required void Function(Map<String, dynamic> event) onEvent}) async {
    if (_connecting || _socket != null) return;
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) return;

    _connecting = true;
    try {
      final uri = Uri.parse(_socketUrl(token));
      final socket = await WebSocket.connect(uri.toString());
      _socket = socket;
      _subscription = socket.listen(
        (raw) {
          if (raw is! String) return;
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) onEvent(decoded);
        },
        onDone: disconnect,
        onError: (_) => disconnect(),
        cancelOnError: true,
      );
      socket.add(jsonEncode({'event': 'ping'}));
    } catch (_) {
      disconnect();
    } finally {
      _connecting = false;
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _socket?.close();
    _socket = null;
    _connecting = false;
  }

  String _socketUrl(String token) {
    final base = VmApiConfig.baseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    return '$base/ws/inbox?token=${Uri.encodeComponent(token)}';
  }
}
