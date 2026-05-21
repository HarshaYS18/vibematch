import 'package:flutter/material.dart';

import '../../wallet/data/wallet_api_service.dart';

class VipProgramPage extends StatefulWidget {
  const VipProgramPage({
    super.key,
    this.initialTabIndex = 0,
    this.vipLevel = 0,
    this.svipLevel = 0,
    this.lifetimeRechargeCoins = 0,
    this.monthlyRechargeCoins = 0,
  });

  final int initialTabIndex;
  final int vipLevel;
  final int svipLevel;
  final int lifetimeRechargeCoins;
  final int monthlyRechargeCoins;

  @override
  State<VipProgramPage> createState() => _VipProgramPageState();
}

class _VipProgramPageState extends State<VipProgramPage> {
  final WalletApiService _walletApi = const WalletApiService();
  late Future<VmWallet> _future;

  @override
  void initState() {
    super.initState();
    _future = _walletApi.getWallet();
  }

  void _reload() => setState(() => _future = _walletApi.getWallet());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF251538),
        elevation: 0,
        title: const Text('VIP & EXP Details', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: FutureBuilder<VmWallet>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: TextButton(onPressed: _reload, child: const Text('Retry backend economy source')));
          }
          final wallet = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                _Hero(wallet: wallet),
                const SizedBox(height: 14),
                _Grid(wallet: wallet),
                const SizedBox(height: 14),
                const _SourceTruthNote(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.wallet});
  final VmWallet wallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF251538), Color(0xFF6D5DF6), Color(0xFFC99A3B)]),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('VIP ${wallet.vipLevel} · SVIP ${wallet.svipLevel}', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('Sent Lv ${wallet.sentLevel} · Receive Lv ${wallet.receiveLevel}', style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        _Progress(label: 'VIP lifetime recharge', value: wallet.vipProgressPercent / 100),
        const SizedBox(height: 10),
        _Progress(label: 'SVIP monthly recharge', value: wallet.svipProgressPercent / 100),
      ]),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontWeight: FontWeight.w800)),
    const SizedBox(height: 6),
    LinearProgressIndicator(value: value.clamp(0, 1), minHeight: 8, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation<Color>(Colors.white)),
  ]);
}

class _Grid extends StatelessWidget {
  const _Grid({required this.wallet});
  final VmWallet wallet;
  @override
  Widget build(BuildContext context) => GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 2,
    childAspectRatio: 2.35,
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    children: [
      _Tile('Coins', _compact(wallet.coinBalance)),
      _Tile('Rubies', _compact(wallet.rubyBalance)),
      _Tile('Lifetime recharge', _compact(wallet.lifetimeRechargeCoins)),
      _Tile('Monthly recharge', _compact(wallet.monthlyRechargeCoins)),
      _Tile('Lifetime sent EXP', _compact(wallet.lifetimeSendExp)),
      _Tile('Lifetime receive EXP', _compact(wallet.lifetimeReceiveExp)),
      _Tile('Monthly sent', _compact(wallet.monthlyGiftCoinsSent)),
      _Tile('Monthly received', _compact(wallet.monthlyGiftCoinsReceived)),
    ],
  );
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF71717A), fontSize: 11, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF111114), fontWeight: FontWeight.w900)),
    ]),
  );
}

class _SourceTruthNote extends StatelessWidget {
  const _SourceTruthNote();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
    child: const Text(
      'One source of truth: this page reads /wallet/me only. VIP, SVIP, Sent Lv, Receive Lv, balances, recharge totals, and gift EXP come from backend economy services. No mock repository or frontend formula is used.',
      style: TextStyle(color: Color(0xFF71717A), fontWeight: FontWeight.w800, height: 1.35),
    ),
  );
}

String _compact(int value) {
  if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}
