import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';
import '../../profile/models/vip_wallet_models.dart';

class WalletRealtimeSyncService {
  WalletRealtimeSyncService._();

  static final WalletRealtimeSyncService instance =
      WalletRealtimeSyncService._();

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

    final wsUrl = _webSocketUrl(
      '/ws/inbox?token=${Uri.encodeQueryComponent(token)}',
    );
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
      if (event == 'experience_updated') {
        _handleExperienceUpdated(decoded);
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
      vipLevel: _firstPositive([
        walletJson['vip_level'],
        vipProgress['level'],
        currentUser.vip.vipLevel,
      ]),
      svipLevel: _firstPositive([
        walletJson['svip_level'],
        svipProgress['level'],
        currentUser.vip.svipLevel,
      ]),
      vipIsActive:
          _firstPositive([
            walletJson['vip_level'],
            vipProgress['level'],
            currentUser.vip.vipLevel,
          ]) >
          0,
      svipIsActive:
          _firstPositive([
            walletJson['svip_level'],
            svipProgress['level'],
            currentUser.vip.svipLevel,
          ]) >
          0,
      svipExpiresAt: currentUser.vip.svipExpiresAt,
      nameGradientKey: currentUser.vip.nameGradientKey,
      nameGradientColors: currentUser.vip.nameGradientColors,
    );

    auth.persistCurrentUser(
      currentUser.copyWith(
        wallet: nextWallet,
        vip: nextVip,
        updatedAt: DateTime.now(),
      ),
    );
  }

  void _handleAllLevelsUpdated(Map<String, dynamic> payload) {
    final economy = _map(payload['economy']);
    if (economy.isEmpty) return;
    final walletJson = _map(payload['wallet']);
    final merged = <String, dynamic>{...economy, ...walletJson};

    final auth = const AuthApiService();
    final currentUser = auth.cachedUser;
    if (currentUser == null) return;

    final sent = _map(merged['sent']);
    final received = _map(merged['received']);
    final vip = _map(merged['vip']);
    final svip = _map(merged['svip']);

    final nextWallet = UserWalletSummary(
      coinBalance: walletJson.containsKey('coin_balance')
          ? _int(walletJson['coin_balance'])
          : currentUser.wallet.coinBalance,
      rubyBalance: walletJson.containsKey('ruby_balance')
          ? _int(walletJson['ruby_balance'])
          : currentUser.wallet.rubyBalance,
      lifetimeCoinsSpent: merged.containsKey('lifetime_coins_spent')
          ? _int(merged['lifetime_coins_spent'])
          : currentUser.wallet.lifetimeCoinsSpent,
      lifetimeCoinsReceivedAsGifts:
          merged.containsKey('lifetime_coins_received_as_gifts')
          ? _int(merged['lifetime_coins_received_as_gifts'])
          : currentUser.wallet.lifetimeCoinsReceivedAsGifts,
      lifetimeRubiesEarned: merged.containsKey('lifetime_rubies_earned')
          ? _int(merged['lifetime_rubies_earned'])
          : currentUser.wallet.lifetimeRubiesEarned,
      monthlyGiftCoinsSent: _int(merged['monthly_gift_coins_sent']),
      monthlyGiftCoinsReceived: _int(merged['monthly_gift_coins_received']),
      lifetimeSendExp: _firstPositive([
        merged['lifetime_send_exp'],
        sent['total_exp'],
        currentUser.wallet.lifetimeSendExp,
      ]),
      lifetimeReceiveExp: _firstPositive([
        merged['lifetime_receive_exp'],
        received['total_exp'],
        currentUser.wallet.lifetimeReceiveExp,
      ]),
      sendLevel: _firstPositive([
        merged['sent_level'],
        sent['level'],
        currentUser.wallet.sendLevel,
      ]),
      receiveLevel: _firstPositive([
        merged['receive_level'],
        received['level'],
        currentUser.wallet.receiveLevel,
      ]),
    );

    final nextVip = UserVipSummary(
      vipLevel: _firstPositive([
        merged['vip_level'],
        vip['level'],
        currentUser.vip.vipLevel,
      ]),
      svipLevel: _firstPositive([
        merged['svip_level'],
        svip['level'],
        currentUser.vip.svipLevel,
      ]),
      vipIsActive:
          _firstPositive([
            merged['vip_level'],
            vip['level'],
            currentUser.vip.vipLevel,
          ]) >
          0,
      svipIsActive:
          _firstPositive([
            merged['svip_level'],
            svip['level'],
            currentUser.vip.svipLevel,
          ]) >
          0,
      svipExpiresAt: currentUser.vip.svipExpiresAt,
      nameGradientKey: currentUser.vip.nameGradientKey,
      nameGradientColors: currentUser.vip.nameGradientColors,
    );

    final nextUser = currentUser.copyWith(
      wallet: nextWallet,
      vip: nextVip,
      updatedAt: DateTime.now(),
    );
    auth.persistCurrentUser(nextUser);
  }

  void _handleExperienceUpdated(Map<String, dynamic> decoded) {
    final auth = const AuthApiService();
    final currentUser = auth.cachedUser;
    if (currentUser == null) return;

    final scope = decoded['scope']?.toString();
    final payload = _map(decoded['payload']);
    final ruby = _map(decoded['ruby']);
    final send = _map(payload['send']);
    final received = _map(payload['receive']);

    final nextWallet = UserWalletSummary(
      coinBalance: currentUser.wallet.coinBalance,
      rubyBalance: ruby.containsKey('balance')
          ? _int(ruby['balance'])
          : currentUser.wallet.rubyBalance,
      lifetimeCoinsSpent: currentUser.wallet.lifetimeCoinsSpent,
      lifetimeCoinsReceivedAsGifts: ruby.containsKey('lifetime_gift_coin_value')
          ? _int(ruby['lifetime_gift_coin_value'])
          : currentUser.wallet.lifetimeCoinsReceivedAsGifts,
      lifetimeRubiesEarned: ruby.containsKey('lifetime_rubies_earned')
          ? _int(ruby['lifetime_rubies_earned'])
          : currentUser.wallet.lifetimeRubiesEarned,
      monthlyGiftCoinsSent: currentUser.wallet.monthlyGiftCoinsSent,
      monthlyGiftCoinsReceived: currentUser.wallet.monthlyGiftCoinsReceived,
      lifetimeSendExp: scope == 'send'
          ? _firstPositive([
              send['total_exp'],
              currentUser.wallet.lifetimeSendExp,
            ])
          : currentUser.wallet.lifetimeSendExp,
      lifetimeReceiveExp: scope == 'receive'
          ? _firstPositive([
              received['total_exp'],
              currentUser.wallet.lifetimeReceiveExp,
            ])
          : currentUser.wallet.lifetimeReceiveExp,
      sendLevel: scope == 'send'
          ? _firstPositive([send['level'], currentUser.wallet.sendLevel])
          : currentUser.wallet.sendLevel,
      receiveLevel: scope == 'receive'
          ? _firstPositive([received['level'], currentUser.wallet.receiveLevel])
          : currentUser.wallet.receiveLevel,
    );

    auth.persistCurrentUser(
      currentUser.copyWith(wallet: nextWallet, updatedAt: DateTime.now()),
    );
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
