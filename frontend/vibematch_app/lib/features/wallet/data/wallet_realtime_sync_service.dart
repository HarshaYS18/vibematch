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
      final event = decoded['event']?.toString();
      if (event == 'wallet_vip_svip_updated') {
        _handleWalletVipSvipUpdated(_map(decoded['payload']));
        return;
      }
      if (event == 'all_levels_updated') {
        _handleAllLevelsUpdated(_map(decoded['payload']));
        return;
      }
    } catch (_) {
      // Ignore malformed realtime events. Full refresh still works through /users/me.
    }
  }

  void _handleWalletVipSvipUpdated(Map<String, dynamic> payload) {
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
  }

  void _handleAllLevelsUpdated(Map<String, dynamic> payload) {
    final economy = _map(payload['economy']);
    if (economy.isEmpty) return;

    final auth = const AuthApiService();
    final currentUser = auth.cachedUser;
    if (currentUser == null) return;

    final sent = _map(economy['sent']);
    final received = _map(economy['received']);
    final vip = _map(economy['vip']);
    final svip = _map(economy['svip']);

    final nextWallet = UserWalletSummary(
      coinBalance: currentUser.wallet.coinBalance,
      rubyBalance: currentUser.wallet.rubyBalance,
      lifetimeCoinsSpent: currentUser.wallet.lifetimeCoinsSpent,
      lifetimeCoinsReceivedAsGifts: currentUser.wallet.lifetimeCoinsReceivedAsGifts,
      lifetimeRubiesEarned: currentUser.wallet.lifetimeRubiesEarned,
      monthlyGiftCoinsSent: _int(economy['monthly_gift_coins_sent']),
      monthlyGiftCoinsReceived: _int(economy['monthly_gift_coins_received']),
      lifetimeSendExp: _firstPositive([economy['lifetime_send_exp'], sent['total_exp'], currentUser.wallet.lifetimeSendExp]),
      lifetimeReceiveExp: _firstPositive([economy['lifetime_receive_exp'], received['total_exp'], currentUser.wallet.lifetimeReceiveExp]),
      sendLevel: _firstPositive([economy['sent_level'], sent['level'], currentUser.wallet.sendLevel]),
      receiveLevel: _firstPositive([economy['receive_level'], received['level'], currentUser.wallet.receiveLevel]),
    );

    final nextVip = UserVipSummary(
      vipLevel: _firstPositive([economy['vip_level'], vip['level'], currentUser.vip.vipLevel]),
      svipLevel: _firstPositive([economy['svip_level'], svip['level'], currentUser.vip.svipLevel]),
      vipIsActive: true,
      svipIsActive: _firstPositive([economy['svip_level'], svip['level'], currentUser.vip.svipLevel]) > 0,
      svipExpiresAt: currentUser.vip.svipExpiresAt,
      nameGradientKey: currentUser.vip.nameGradientKey,
      nameGradientColors: currentUser.vip.nameGradientColors,
    );

    final nextUser = currentUser.copyWith(wallet: nextWallet, vip: nextVip, updatedAt: DateTime.now());
    auth.persistCurrentUser(nextUser);
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

int _firstPositive(List<dynamic> values) {
  for (final value in values) {
    final parsed = _int(value);
    if (parsed > 0) return parsed;
  }
  return 0;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
