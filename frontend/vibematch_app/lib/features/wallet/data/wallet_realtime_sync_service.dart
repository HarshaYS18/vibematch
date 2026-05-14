import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';
import '../../profile/models/vip_wallet_models.dart';

class WalletRealtimeSyncService {
  WalletRealtimeSyncService._();

  static final WalletRealtimeSyncService instance = WalletRealtimeSyncService._();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    final auth = const AuthApiService();
    final token = auth.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      _started = false;
      return;
    }

    final wsUrl = _webSocketUrl('/ws/inbox?token=${Uri.encodeQueryComponent(token)}');
    try {
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel = channel;
      _subscription = channel.stream.listen(
        _handleMessage,
        onError: (_) => _stopInternal(),
        onDone: _stopInternal,
        cancelOnError: true,
      );
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          _channel?.sink.add(jsonEncode({'event': 'ping'}));
        } catch (_) {
          _stopInternal();
        }
      });
    } catch (_) {
      _stopInternal();
    }
  }

  Future<void> stop() async {
    _started = false;
    await _subscription?.cancel();
    _subscription = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void _stopInternal() {
    _started = false;
    _subscription?.cancel();
    _subscription = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _channel = null;
  }

  void _handleMessage(dynamic raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map<String, dynamic>) return;
      if (decoded['event'] != 'wallet_vip_svip_updated') return;

      final payload = _map(decoded['payload']);
      final walletJson = _map(payload['wallet']);
      if (walletJson.isEmpty) return;

      final auth = const AuthApiService();
      final currentUser = auth.cachedUser;
      if (currentUser == null) return;

      final nextWallet = UserWalletSummary.fromJson(walletJson);
      final vipProgress = _map(walletJson['vip']);
      final svipProgress = _map(walletJson['svip']);
      final nextVip = UserVipSummary(
        vipLevel: _int(vipProgress['level']),
        svipLevel: _int(svipProgress['level']),
        vipIsActive: true,
        svipIsActive: _int(svipProgress['level']) > 0,
        svipExpiresAt: currentUser.vip.svipExpiresAt,
        nameGradientKey: currentUser.vip.nameGradientKey,
        nameGradientColors: currentUser.vip.nameGradientColors,
      );

      AuthUserRealtimeService.instance.publish(
        currentUser.copyWith(wallet: nextWallet, vip: nextVip, updatedAt: DateTime.now()),
      );
    } catch (_) {
      // Ignore malformed realtime events. Full refresh still works through /users/me.
    }
  }

  String _webSocketUrl(String path) {
    final base = VmApiConfig.baseUrl;
    final scheme = base.startsWith('https://') ? 'wss://' : 'ws://';
    final noScheme = base.replaceFirst(RegExp(r'^https?://'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$scheme$noScheme$normalizedPath';
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
