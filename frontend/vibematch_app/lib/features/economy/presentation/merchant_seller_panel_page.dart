import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../auth/data/auth_local_storage.dart';
import '../../../core/network/vm_api_config.dart';

class MerchantSellerPanelPage extends StatefulWidget {
  const MerchantSellerPanelPage({super.key});

  @override
  State<MerchantSellerPanelPage> createState() => _MerchantSellerPanelPageState();
}

class _MerchantSellerPanelPageState extends State<MerchantSellerPanelPage> {
  final _api = const _EconomyPanelApi();
  late Future<_EconomyDashboard> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _api.fetchDashboard();
  }

  void _reload() {
    setState(() {
      _dashboardFuture = _api.fetchDashboard();
    });
  }

  void _showAction(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFAF7F1),
        foregroundColor: const Color(0xFF251538),
        title: const Text('Merchant & Seller Panel', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Refresh economy panel',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_EconomyDashboard>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _PanelLoadingState();
          }

          if (snapshot.hasError) {
            return _PanelErrorState(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }

          final dashboard = snapshot.data;
          if (dashboard == null) {
            return _PanelErrorState(message: 'Economy dashboard was empty.', onRetry: _reload);
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            color: const Color(0xFF251538),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              children: [
                _InfoBanner(
                  title: 'Pool coins are inventory only',
                  body: dashboard.note,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _WalletCard(
                        title: 'Personal Coins',
                        value: dashboard.wallet.coinBalance,
                        icon: Icons.monetization_on_rounded,
                        color: const Color(0xFFC99A3B),
                        note: 'Spendable by this account',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _WalletCard(
                        title: 'Rubies',
                        value: dashboard.wallet.rubyBalance,
                        icon: Icons.diamond_rounded,
                        color: const Color(0xFFE84C72),
                        note: '${_formatNumber(dashboard.wallet.withdrawableRubies)} withdrawable',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SectionTitle(title: 'Supply Pools', subtitle: 'Inventory balances, separated from personal wallet'),
                const SizedBox(height: 10),
                _PoolCard(
                  title: 'Seller Supply Pool',
                  value: dashboard.sellerPool?.balance ?? 0,
                  poolStatus: dashboard.sellerPool?.status ?? 'NOT CREATED',
                  icon: Icons.storefront_rounded,
                  color: const Color(0xFF12C7B7),
                  subtitle: dashboard.sellerPool == null
                      ? 'No seller inventory pool assigned to this account yet.'
                      : 'Can sell coins to users through official sale flow only.',
                  actions: [
                    _PanelAction(label: 'Sell Coins', icon: Icons.person_add_alt_1_rounded, onTap: () => _showAction(context, 'Seller coin sale form will open.')),
                    _PanelAction(label: 'Sale Logs', icon: Icons.receipt_long_rounded, onTap: () => _showAction(context, 'Seller sale ledger will open.')),
                  ],
                ),
                const SizedBox(height: 12),
                _PoolCard(
                  title: 'Merchant Supply Pool',
                  value: dashboard.merchantPool?.balance ?? 0,
                  poolStatus: dashboard.merchantPool?.status ?? 'NOT CREATED',
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF6D5DF6),
                  subtitle: dashboard.merchantPool == null
                      ? 'No merchant inventory pool assigned to this account yet.'
                      : 'Can distribute to sellers or sell directly when permission allows.',
                  actions: [
                    _PanelAction(label: 'Allocate', icon: Icons.call_split_rounded, onTap: () => _showAction(context, 'Merchant allocation flow will open.')),
                    _PanelAction(label: 'Ledger', icon: Icons.history_rounded, onTap: () => _showAction(context, 'Merchant pool ledger will open.')),
                  ],
                ),
                const SizedBox(height: 12),
                _PoolCard(
                  title: 'Gaming Pool',
                  value: dashboard.gamingPool?.balance ?? 0,
                  poolStatus: dashboard.gamingPool?.status ?? 'NOT CREATED',
                  icon: Icons.sports_esports_rounded,
                  color: const Color(0xFFE84C72),
                  subtitle: dashboard.gamingPool == null
                      ? 'No gaming pool assigned to this account yet.'
                      : 'Separate game liquidity/risk pool. Game winnings pay coins only; games do not mint rubies.',
                  actions: [
                    _PanelAction(label: 'Game Pools', icon: Icons.casino_rounded, onTap: () => _showAction(context, 'Game pool dashboard will open.')),
                    _PanelAction(label: 'Risk Logs', icon: Icons.shield_rounded, onTap: () => _showAction(context, 'Gaming risk logs will open.')),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionTitle(title: 'Wallet Details', subtitle: 'Real values from /economy/me'),
                const SizedBox(height: 10),
                _WalletDetailCard(wallet: dashboard.wallet),
                const SizedBox(height: 16),
                _SectionTitle(title: 'Economy Rules', subtitle: 'Backend source of truth'),
                const SizedBox(height: 10),
                const _RuleList(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EconomyPanelApi {
  const _EconomyPanelApi();

  Future<_EconomyDashboard> fetchDashboard() async {
    final token = await AuthLocalStorage().getAccessToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('No saved login token found. Login again, then open this panel.');
    }

    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/economy/me')),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load economy dashboard (${response.statusCode}): ${response.body}');
    }

    return _EconomyDashboard.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

class _EconomyDashboard {
  const _EconomyDashboard({
    required this.wallet,
    required this.sellerPool,
    required this.merchantPool,
    required this.gamingPool,
    required this.note,
  });

  final _EconomyWallet wallet;
  final _EconomyPool? sellerPool;
  final _EconomyPool? merchantPool;
  final _EconomyPool? gamingPool;
  final String note;

  factory _EconomyDashboard.fromJson(Map<String, dynamic> json) {
    return _EconomyDashboard(
      wallet: _EconomyWallet.fromJson(json['wallet'] as Map<String, dynamic>),
      sellerPool: _EconomyPool.fromNullableJson(json['seller_pool']),
      merchantPool: _EconomyPool.fromNullableJson(json['merchant_pool']),
      gamingPool: _EconomyPool.fromNullableJson(json['gaming_pool']),
      note: json['note'] as String? ?? 'Supply pool coins are inventory only and never appear in normal coin balance.',
    );
  }
}

class _EconomyWallet {
  const _EconomyWallet({
    required this.userId,
    required this.coinBalance,
    required this.rubyBalance,
    required this.withdrawableRubies,
    required this.pendingWithdrawRubies,
    required this.lifetimeCoinsSpent,
    required this.lifetimeRubiesEarned,
  });

  final int userId;
  final int coinBalance;
  final int rubyBalance;
  final int withdrawableRubies;
  final int pendingWithdrawRubies;
  final int lifetimeCoinsSpent;
  final int lifetimeRubiesEarned;

  factory _EconomyWallet.fromJson(Map<String, dynamic> json) {
    return _EconomyWallet(
      userId: _readInt(json['user_id']),
      coinBalance: _readInt(json['coin_balance']),
      rubyBalance: _readInt(json['ruby_balance']),
      withdrawableRubies: _readInt(json['withdrawable_rubies']),
      pendingWithdrawRubies: _readInt(json['pending_withdraw_rubies']),
      lifetimeCoinsSpent: _readInt(json['lifetime_coins_spent']),
      lifetimeRubiesEarned: _readInt(json['lifetime_rubies_earned']),
    );
  }
}

class _EconomyPool {
  const _EconomyPool({
    required this.id,
    required this.ownerUserId,
    required this.poolType,
    required this.balance,
    required this.reservedBalance,
    required this.status,
  });

  final int id;
  final int? ownerUserId;
  final String poolType;
  final int balance;
  final int reservedBalance;
  final String status;

  static _EconomyPool? fromNullableJson(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map<String, dynamic>) return null;
    return _EconomyPool.fromJson(raw);
  }

  factory _EconomyPool.fromJson(Map<String, dynamic> json) {
    return _EconomyPool(
      id: _readInt(json['id']),
      ownerUserId: json['owner_user_id'] == null ? null : _readInt(json['owner_user_id']),
      poolType: json['pool_type'] as String? ?? 'UNKNOWN_POOL',
      balance: _readInt(json['balance']),
      reservedBalance: _readInt(json['reserved_balance']),
      status: json['status'] as String? ?? 'UNKNOWN',
    );
  }
}

int _readInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? 0;
  return 0;
}

String _formatNumber(int value) {
  final sign = value < 0 ? '-' : '';
  final raw = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    final reverseIndex = raw.length - index;
    buffer.write(raw[index]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(',');
    }
  }
  return '$sign$buffer';
}

class _PanelLoadingState extends StatelessWidget {
  const _PanelLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF251538)),
    );
  }
}

class _PanelErrorState extends StatelessWidget {
  const _PanelErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFFECE2D8))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFE84C72), size: 38),
              const SizedBox(height: 10),
              const Text('Could not load economy panel', style: TextStyle(color: Color(0xFF251538), fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF251538), foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF251538), Color(0xFF4A2A63)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.16), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.lock_rounded, color: Color(0xFFFFD36A))),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(body, style: TextStyle(color: Colors.white.withValues(alpha: 0.76), fontSize: 12.5, height: 1.28, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.title, required this.value, required this.icon, required this.color, required this.note});
  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 25),
        const SizedBox(height: 10),
        Text(_formatNumber(value), style: const TextStyle(color: Color(0xFF251538), fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(note, style: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 10.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _WalletDetailCard extends StatelessWidget {
  const _WalletDetailCard({required this.wallet});

  final _EconomyWallet wallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Column(
        children: [
          _DetailLine(label: 'User ID', value: wallet.userId.toString()),
          _DetailLine(label: 'Lifetime Coins Spent', value: _formatNumber(wallet.lifetimeCoinsSpent)),
          _DetailLine(label: 'Lifetime Rubies Earned', value: _formatNumber(wallet.lifetimeRubiesEarned)),
          _DetailLine(label: 'Pending Withdraw Rubies', value: _formatNumber(wallet.pendingWithdrawRubies)),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 12, fontWeight: FontWeight.w800))),
          Text(value, style: const TextStyle(color: Color(0xFF251538), fontSize: 13, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _PoolCard extends StatelessWidget {
  const _PoolCard({required this.title, required this.value, required this.poolStatus, required this.icon, required this.color, required this.subtitle, required this.actions});
  final String title;
  final int value;
  final String poolStatus;
  final IconData icon;
  final Color color;
  final String subtitle;
  final List<_PanelAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)), child: Icon(icon, color: color)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 11.5, height: 1.25, fontWeight: FontWeight.w700)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_formatNumber(value), style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.w900)),
            const Text('pool coins', style: TextStyle(color: Color(0xFF8C7B8F), fontSize: 10, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(poolStatus, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
          ]),
        ]),
        const SizedBox(height: 12),
        Row(children: [for (var index = 0; index < actions.length; index++) ...[Expanded(child: actions[index]), if (index != actions.length - 1) const SizedBox(width: 10)]]),
      ]),
    );
  }
}

class _PanelAction extends StatelessWidget {
  const _PanelAction({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE2D8))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: const Color(0xFF251538), size: 16), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Color(0xFF251538), fontSize: 12, fontWeight: FontWeight.w900))]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 21, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 12, fontWeight: FontWeight.w700))]);
}

class _RuleList extends StatelessWidget {
  const _RuleList();
  @override
  Widget build(BuildContext context) {
    const rules = ['Coins are spendable app currency.', 'Rubies are earned from receiving gifts and are withdrawable after review.', '100 received coins = 30 rubies by default.', 'Seller and merchant pool coins are supply inventory, not normal balance.', 'Gaming pools are separate from social gifts and pay coins only.'];
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Column(children: [for (final rule in rules) Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle_rounded, color: Color(0xFF12C7B7), size: 18), const SizedBox(width: 8), Expanded(child: Text(rule, style: const TextStyle(color: Color(0xFF251538), fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.25)))]))]),
    );
  }
}
