import 'package:flutter/material.dart';

import '../data/wallet_api_service.dart';
import 'models/wallet_models.dart';
import 'widgets/wallet_shared_widgets.dart';

class WalletPageModular extends StatefulWidget {
  const WalletPageModular({
    super.key,
    this.initialSection = WalletSection.coins,
  });

  final WalletSection initialSection;

  @override
  State<WalletPageModular> createState() => _WalletPageModularState();
}

class _WalletPageModularState extends State<WalletPageModular> {
  final WalletApiService _walletApi = const WalletApiService();
  final TextEditingController _rubyConvertController = TextEditingController();

  late WalletSection _selectedSection = widget.initialSection;
  VmWallet? _wallet;
  List<VmWalletLedgerEntry> _ledger = const [];
  bool _loading = true;
  bool _working = false;
  String? _error;

  static const List<int> _rechargeAmountsInr = [
    100,
    500,
    1000,
    5000,
    10000,
    50000,
    100000,
    500000,
  ];

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  @override
  void dispose() {
    _rubyConvertController.dispose();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final wallet = await _walletApi.getWallet();
      final ledger = await _walletApi.getLedger(limit: 40);
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _ledger = ledger;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _recharge(int amountInr) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final wallet = await _walletApi.recharge(amountInr: amountInr);
      final ledger = await _walletApi.getLedger(limit: 40);
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _ledger = ledger;
      });
      _toast('Recharge added ₹$amountInr = ${formatWalletNumber(amountInr * 1000)} coins');
    } catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _convertRuby() async {
    final amount = int.tryParse(_rubyConvertController.text.trim()) ?? 0;
    if (amount <= 0) {
      _toast('Enter valid Ruby amount');
      return;
    }
    if (_working) return;
    setState(() => _working = true);
    try {
      final wallet = await _walletApi.convertRuby(rubyAmount: amount);
      final ledger = await _walletApi.getLedger(limit: 40);
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _ledger = ledger;
        _rubyConvertController.clear();
      });
      _toast('$amount Ruby converted to $amount coins');
    } catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: WalletColors.deep,
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: WalletColors.bg,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              border: const Border(bottom: BorderSide(color: WalletColors.border)),
              boxShadow: [
                BoxShadow(
                  color: WalletColors.deep.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: WalletColors.deep),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wallet',
                        style: TextStyle(
                          color: WalletColors.deep,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.7,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Real coins, Ruby, VIP and SVIP',
                        style: TextStyle(
                          color: WalletColors.plum,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                WalletHeaderIconButton(
                  icon: Icons.refresh_rounded,
                  onTap: _loadWallet,
                ),
              ],
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: WalletColors.aqua));
    }

    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: WalletColors.coral, size: 42),
              const SizedBox(height: 10),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: WalletColors.deep,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              WalletPrimarySmallButton(text: 'Retry', onTap: _loadWallet),
            ],
          ),
        ),
      );
    }

    final wallet = _wallet;
    if (wallet == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _loadWallet,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _RealWalletOverviewCard(wallet: wallet, selectedSection: _selectedSection),
          const SizedBox(height: 14),
          _WalletSectionTabs(
            selectedSection: _selectedSection,
            onChanged: (section) => setState(() => _selectedSection = section),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _selectedSection == WalletSection.coins
                ? _CoinsRealSection(
                    key: const ValueKey('coins_real'),
                    wallet: wallet,
                    rechargeAmountsInr: _rechargeAmountsInr,
                    working: _working,
                    onRecharge: _recharge,
                  )
                : _RubyRealSection(
                    key: const ValueKey('ruby_real'),
                    wallet: wallet,
                    controller: _rubyConvertController,
                    working: _working,
                    onConvert: _convertRuby,
                  ),
          ),
          const SizedBox(height: 14),
          _RealLedgerCard(entries: _ledger),
        ],
      ),
    );
  }
}

class _RealWalletOverviewCard extends StatelessWidget {
  const _RealWalletOverviewCard({required this.wallet, required this.selectedSection});

  final VmWallet wallet;
  final WalletSection selectedSection;

  @override
  Widget build(BuildContext context) {
    final isCoins = selectedSection == WalletSection.coins;
    final value = isCoins ? wallet.coinBalance : wallet.rubyBalance;
    final title = isCoins ? 'Coin Balance' : 'Ruby Balance';
    final icon = isCoins ? Icons.monetization_on_rounded : Icons.diamond_rounded;
    final colors = isCoins
        ? const [Color(0xFFFFD166), Color(0xFFE84C72), Color(0xFF6D5DF6)]
        : const [Color(0xFFE84C72), Color(0xFF8C5CF6), Color(0xFF12C7B7)];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      formatWalletNumber(value),
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.8),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            wallet.coinPriceText,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _LevelPill(label: 'VIP', level: wallet.vipLevel, maxLevel: wallet.vipMaxLevel, progress: wallet.vipProgressPercent)),
              const SizedBox(width: 10),
              Expanded(child: _LevelPill(label: 'SVIP', level: wallet.svipLevel, maxLevel: wallet.svipMaxLevel, progress: wallet.svipProgressPercent)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.label, required this.level, required this.maxLevel, required this.progress});

  final String label;
  final int level;
  final int maxLevel;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label $level/$maxLevel', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: (progress / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Text('${progress.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _WalletSectionTabs extends StatelessWidget {
  const _WalletSectionTabs({required this.selectedSection, required this.onChanged});

  final WalletSection selectedSection;
  final ValueChanged<WalletSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: WalletColors.border)),
      child: Row(
        children: WalletSection.values.map((section) {
          final selected = section == selectedSection;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(section),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 42,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: selected ? WalletColors.deep : Colors.transparent),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(section.icon, color: selected ? Colors.white : const Color(0xFF8C8198), size: 18),
                    const SizedBox(width: 7),
                    Text(section.label, style: TextStyle(color: selected ? Colors.white : WalletColors.plum, fontSize: 13, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CoinsRealSection extends StatelessWidget {
  const _CoinsRealSection({required this.wallet, required this.rechargeAmountsInr, required this.working, required this.onRecharge, super.key});

  final VmWallet wallet;
  final List<int> rechargeAmountsInr;
  final bool working;
  final ValueChanged<int> onRecharge;

  @override
  Widget build(BuildContext context) {
    return WalletWhiteCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.add_card_rounded, color: WalletColors.gold, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Recharge Coins', style: TextStyle(color: WalletColors.deep, fontSize: 16, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '₹100 = 1,00,000 coins. Recharge updates coin balance, lifetime VIP and monthly SVIP.',
            style: const TextStyle(color: Color(0xFF6F627A), fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _InfoLine(label: 'Lifetime recharge', value: '${formatWalletNumber(wallet.lifetimeRechargeCoins)} coins'),
          _InfoLine(label: 'Monthly recharge', value: '${formatWalletNumber(wallet.monthlyRechargeCoins)} coins'),
          _InfoLine(label: 'Highest VIP target', value: '₹4,00,00,000'),
          _InfoLine(label: 'Highest SVIP monthly target', value: '₹20,00,000'),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rechargeAmountsInr.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.55),
            itemBuilder: (context, index) {
              final amount = rechargeAmountsInr[index];
              return _RechargeCard(amountInr: amount, working: working, onTap: () => onRecharge(amount));
            },
          ),
        ],
      ),
    );
  }
}

class _RechargeCard extends StatelessWidget {
  const _RechargeCard({required this.amountInr, required this.working, required this.onTap});

  final int amountInr;
  final bool working;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final coins = amountInr * 1000;
    return Material(
      color: WalletColors.bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: working ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: WalletColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.monetization_on_rounded, color: WalletColors.gold, size: 24),
              const Spacer(),
              Text('${formatWalletNumber(coins)} coins', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: WalletColors.deep, fontSize: 13, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text('₹$amountInr', style: const TextStyle(color: WalletColors.gold, fontSize: 13, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RubyRealSection extends StatelessWidget {
  const _RubyRealSection({required this.wallet, required this.controller, required this.working, required this.onConvert, super.key});

  final VmWallet wallet;
  final TextEditingController controller;
  final bool working;
  final VoidCallback onConvert;

  @override
  Widget build(BuildContext context) {
    return WalletWhiteCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.diamond_rounded, color: WalletColors.coral, size: 21), SizedBox(width: 8), Expanded(child: Text('Ruby Actions', style: TextStyle(color: WalletColors.deep, fontSize: 16, fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 8),
          _InfoLine(label: 'Ruby balance', value: formatWalletNumber(wallet.rubyBalance)),
          _InfoLine(label: 'Coin balance', value: formatWalletNumber(wallet.coinBalance)),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter Ruby amount to convert',
              filled: true,
              fillColor: WalletColors.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: WalletColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: WalletColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: WalletColors.coral)),
            ),
          ),
          const SizedBox(height: 10),
          WalletPrimarySmallButton(text: working ? 'Please wait...' : 'Convert 1 Ruby = 1 Coin', onTap: working ? () {} : onConvert),
          const SizedBox(height: 12),
          const Text(
            'Withdrawal flow is review-only later. Current real logic supports Ruby-to-coin conversion and ledger entries.',
            style: TextStyle(color: Color(0xFF6F627A), fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RealLedgerCard extends StatelessWidget {
  const _RealLedgerCard({required this.entries});

  final List<VmWalletLedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    return WalletWhiteCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Real Ledger', style: TextStyle(color: WalletColors.deep, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Text('No wallet ledger entries yet.', style: TextStyle(color: Color(0xFF6F627A), fontSize: 12, fontWeight: FontWeight.w700))
          else
            ...entries.take(12).map((entry) => _LedgerRow(entry: entry)),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});

  final VmWalletLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final credit = entry.direction == 'credit';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: WalletColors.bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: WalletColors.border)),
      child: Row(
        children: [
          Icon(credit ? Icons.add_circle_rounded : Icons.remove_circle_rounded, color: credit ? WalletColors.aqua : WalletColors.coral, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.reason ?? entry.source, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: WalletColors.deep, fontSize: 12.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('${entry.source} • ${entry.currency}', style: const TextStyle(color: Color(0xFF6F627A), fontSize: 10.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Text('${credit ? '+' : '-'}${formatWalletNumber(entry.amount)}', style: TextStyle(color: credit ? WalletColors.aqua : WalletColors.coral, fontSize: 12.5, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF6F627A), fontSize: 11.5, fontWeight: FontWeight.w700))),
          Text(value, style: const TextStyle(color: WalletColors.deep, fontSize: 11.5, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
