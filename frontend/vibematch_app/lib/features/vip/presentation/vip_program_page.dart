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
  static const Color _bg = Color(0xFF080713);
  static const Color _panel = Color(0xFF141121);
  static const Color _gold = Color(0xFFFFD36E);
  static const Color _text = Color(0xFFF9F2FF);
  static const Color _muted = Color(0xFFB9ADC8);

  final WalletApiService _walletApi = const WalletApiService();
  late int _tab;
  late Future<VmWallet> _future;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTabIndex.clamp(0, 3).toInt();
    _future = _walletApi.getWallet();
  }

  void _reload() => setState(() => _future = _walletApi.getWallet());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: () => Navigator.of(context).maybePop()),
            _Tabs(value: _tab, onChanged: (value) => setState(() => _tab = value)),
            Expanded(
              child: FutureBuilder<VmWallet>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(color: _gold));
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return _ErrorState(onRetry: _reload);
                  }
                  final wallet = snapshot.data!;
                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    color: _gold,
                    child: IndexedStack(
                      index: _tab,
                      children: [
                        _LevelView(
                          title: 'VIP ${wallet.vipLevel}',
                          subtitle: 'Lifetime recharge royalty',
                          icon: Icons.workspace_premium_rounded,
                          current: wallet.lifetimeRechargeCoins,
                          target: wallet.vipMaxLifetimeRechargeCoins,
                          progress: wallet.vipProgressPercent / 100,
                          colors: const [Color(0xFF2B173F), Color(0xFF6D37D8), Color(0xFFE9B75F)],
                          stats: [
                            _Metric('Coins', _compact(wallet.coinBalance), Icons.paid_rounded),
                            _Metric('Rubies', _compact(wallet.rubyBalance), Icons.diamond_rounded),
                            _Metric('Max VIP', '${wallet.vipMaxLevel}', Icons.military_tech_rounded),
                            _Metric('Recharge', _compact(wallet.lifetimeRechargeCoins), Icons.bolt_rounded),
                          ],
                          note: 'VIP is rendered from backend /wallet/me only. Level, progress and recharge EXP come from the canonical wallet ledger and economy rules.',
                        ),
                        _LevelView(
                          title: 'SVIP ${wallet.svipLevel}',
                          subtitle: 'Monthly elite crown',
                          icon: Icons.diamond_rounded,
                          current: wallet.monthlyRechargeCoins,
                          target: wallet.svipMaxMonthlyRechargeCoins,
                          progress: wallet.svipProgressPercent / 100,
                          colors: const [Color(0xFF071D2E), Color(0xFF0FB9AD), Color(0xFF8057F6)],
                          stats: [
                            _Metric('This month', _compact(wallet.monthlyRechargeCoins), Icons.calendar_month_rounded),
                            _Metric('Period', wallet.monthlyRechargePeriod.isEmpty ? 'Current' : wallet.monthlyRechargePeriod, Icons.event_rounded),
                            _Metric('Max SVIP', '${wallet.svipMaxLevel}', Icons.emoji_events_rounded),
                            _Metric('Coin rule', wallet.coinPriceText, Icons.verified_rounded),
                          ],
                          note: 'SVIP is recalculated from backend monthly recharge totals. Flutter does not create temporary SVIP levels or local thresholds.',
                        ),
                        _LevelView(
                          title: 'Sent Lv ${wallet.sentLevel}',
                          subtitle: 'Lifetime sender EXP',
                          icon: Icons.north_east_rounded,
                          current: wallet.lifetimeSendExp,
                          target: wallet.lifetimeSendExp <= 0 ? 1 : wallet.lifetimeSendExp,
                          progress: 1,
                          colors: const [Color(0xFF30194D), Color(0xFF7C4DFF), Color(0xFFFF5D9E)],
                          stats: [
                            _Metric('Lifetime EXP', _compact(wallet.lifetimeSendExp), Icons.auto_graph_rounded),
                            _Metric('Monthly sent', _compact(wallet.monthlyGiftCoinsSent), Icons.local_fire_department_rounded),
                            _Metric('Coins', _compact(wallet.coinBalance), Icons.paid_rounded),
                            _Metric('VIP', '${wallet.vipLevel}', Icons.workspace_premium_rounded),
                          ],
                          note: 'Sent Lv is backend gift-send EXP. The app does not keep a second sender-level source in the page.',
                        ),
                        _LevelView(
                          title: 'Receive Lv ${wallet.receiveLevel}',
                          subtitle: 'Lifetime receiver EXP',
                          icon: Icons.south_west_rounded,
                          current: wallet.lifetimeReceiveExp,
                          target: wallet.lifetimeReceiveExp <= 0 ? 1 : wallet.lifetimeReceiveExp,
                          progress: 1,
                          colors: const [Color(0xFF12312D), Color(0xFF12C7B7), Color(0xFFFFD36E)],
                          stats: [
                            _Metric('Lifetime EXP', _compact(wallet.lifetimeReceiveExp), Icons.auto_graph_rounded),
                            _Metric('Monthly received', _compact(wallet.monthlyGiftCoinsReceived), Icons.volunteer_activism_rounded),
                            _Metric('Rubies earned', _compact(wallet.lifetimeRubiesEarned), Icons.diamond_rounded),
                            _Metric('SVIP', '${wallet.svipLevel}', Icons.verified_rounded),
                          ],
                          note: 'Receive Lv is backend gift-receive EXP. The display is a read-only reflection of backend economy state.',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 6),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _VipProgramPageState._text, size: 19)),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Royal Economy', style: TextStyle(color: _VipProgramPageState._text, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.7)),
                Text('VIP · SVIP · EXP details', style: TextStyle(color: _VipProgramPageState._muted, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: _VipProgramPageState._gold.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: _VipProgramPageState._gold.withValues(alpha: 0.32))),
            child: const Row(children: [Icon(Icons.security_rounded, color: _VipProgramPageState._gold, size: 15), SizedBox(width: 5), Text('Backend', style: TextStyle(color: _VipProgramPageState._gold, fontWeight: FontWeight.w900, fontSize: 11))]),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['VIP', 'SVIP', 'Sent Lv', 'Receive Lv'];
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: labels.length,
        itemBuilder: (_, index) {
          final selected = value == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? _VipProgramPageState._gold : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: selected ? _VipProgramPageState._gold : Colors.white.withValues(alpha: 0.10)),
                ),
                child: Text(labels[index], style: TextStyle(color: selected ? const Color(0xFF251538) : _VipProgramPageState._muted, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LevelView extends StatelessWidget {
  const _LevelView({required this.title, required this.subtitle, required this.icon, required this.current, required this.target, required this.progress, required this.colors, required this.stats, required this.note});
  final String title;
  final String subtitle;
  final IconData icon;
  final int current;
  final int target;
  final double progress;
  final List<Color> colors;
  final List<_Metric> stats;
  final String note;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        _HeroCard(title: title, subtitle: subtitle, icon: icon, current: current, target: target, progress: progress, colors: colors),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.25,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: stats.map((item) => _MetricCard(item: item)).toList(),
        ),
        const SizedBox(height: 14),
        _SourceCard(note: note),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.title, required this.subtitle, required this.icon, required this.current, required this.target, required this.progress, required this.colors});
  final String title;
  final String subtitle;
  final IconData icon;
  final int current;
  final int target;
  final double progress;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 224,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.36), blurRadius: 34, offset: const Offset(0, 18))],
      ),
      child: Stack(children: [
        Positioned(right: -18, top: -18, child: Icon(icon, size: 142, color: Colors.white.withValues(alpha: 0.12))),
        Positioned(right: 8, top: 6, child: Icon(Icons.auto_awesome_rounded, color: Colors.white.withValues(alpha: 0.72), size: 24)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.1)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontWeight: FontWeight.w800)),
          const Spacer(),
          Row(children: [
            _Glass(label: 'Current', value: _compact(current)),
            const SizedBox(width: 10),
            _Glass(label: 'Target', value: _compact(target)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: progress.clamp(0, 1), minHeight: 8, backgroundColor: Colors.white.withValues(alpha: 0.18), valueColor: const AlwaysStoppedAnimation<Color>(Colors.white)),
          ),
        ]),
      ]),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.66), fontSize: 10.5, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
    ]),
  ));
}

class _Metric {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.item});
  final _Metric item;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: _VipProgramPageState._panel, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
    child: Row(children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: _VipProgramPageState._gold.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(15)), child: Icon(item.icon, color: _VipProgramPageState._gold, size: 19)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _VipProgramPageState._muted, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(item.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _VipProgramPageState._text, fontWeight: FontWeight.w900)),
      ])),
    ]),
  );
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.note});
  final String note;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: _VipProgramPageState._panel, borderRadius: BorderRadius.circular(24), border: Border.all(color: _VipProgramPageState._gold.withValues(alpha: 0.18))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.security_rounded, color: _VipProgramPageState._gold, size: 22),
      const SizedBox(width: 10),
      Expanded(child: Text(note, style: const TextStyle(color: _VipProgramPageState._muted, fontWeight: FontWeight.w800, height: 1.36))),
    ]),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: TextButton(onPressed: onRetry, child: const Text('Retry backend economy source', style: TextStyle(color: _VipProgramPageState._gold, fontWeight: FontWeight.w900))));
}

String _compact(int value) {
  if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}
