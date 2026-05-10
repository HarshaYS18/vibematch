import 'package:flutter/material.dart';

import '../../auth/data/auth_api_service.dart';
import '../../profile/data/coin_sales_api_service.dart';

class MerchantSellerPanelPage extends StatefulWidget {
  const MerchantSellerPanelPage({super.key});

  @override
  State<MerchantSellerPanelPage> createState() => _MerchantSellerPanelPageState();
}

class _MerchantSellerPanelPageState extends State<MerchantSellerPanelPage> {
  final CoinSalesApiService _coinSalesApi = const CoinSalesApiService();
  final AuthApiService _authApi = const AuthApiService();
  final TextEditingController _buyerIdController = TextEditingController();
  final TextEditingController _coinAmountController = TextEditingController(text: '10000');
  final TextEditingController _paymentAmountController = TextEditingController(text: '0');
  final TextEditingController _reasonController = TextEditingController(text: 'Merchant/Seller coin sale');

  late Future<_MerchantSellerDashboard> _dashboardFuture;
  int? _selectedPoolId;
  bool _selling = false;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
  }

  @override
  void dispose() {
    _buyerIdController.dispose();
    _coinAmountController.dispose();
    _paymentAmountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<_MerchantSellerDashboard> _loadDashboard() async {
    final user = await _authApi.getCurrentUser(forceRefresh: true);
    final pools = await _coinSalesApi.mySupplyPools();
    if (_selectedPoolId == null && pools.isNotEmpty) {
      _selectedPoolId = pools.first.id;
    }
    return _MerchantSellerDashboard(userName: user.displayName ?? user.username ?? 'Seller', personalCoins: user.wallet.coinBalance, pools: pools);
  }

  void _reload() {
    setState(() {
      _dashboardFuture = _loadDashboard();
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538)));
  }

  Future<void> _sellCoins() async {
    final buyerPublicId = int.tryParse(_buyerIdController.text.trim());
    final coinAmount = int.tryParse(_coinAmountController.text.trim());
    final paymentAmount = int.tryParse(_paymentAmountController.text.trim()) ?? 0;
    final reason = _reasonController.text.trim();
    final sourcePoolId = _selectedPoolId;

    if (buyerPublicId == null || buyerPublicId <= 0) {
      _toast('Enter valid buyer public user ID.');
      return;
    }
    if (coinAmount == null || coinAmount <= 0) {
      _toast('Enter valid coin amount.');
      return;
    }
    if (sourcePoolId == null) {
      _toast('No supply pool selected. Ask Owner/Super Owner to grant supply.');
      return;
    }
    if (reason.length < 3) {
      _toast('Enter sale reason.');
      return;
    }
    if (_selling) return;

    setState(() => _selling = true);
    try {
      final result = await _coinSalesApi.sellToUser(
        targetPublicUserId: buyerPublicId,
        coinAmount: coinAmount,
        paymentAmount: paymentAmount,
        paymentCurrency: 'INR',
        sourcePoolId: sourcePoolId,
        reason: reason,
      );
      if (!mounted) return;
      _toast('Coins delivered. Buyer balance: ${_formatNumber(result.buyerWalletCoinBalance)}');
      _buyerIdController.clear();
      setState(() {
        _dashboardFuture = _loadDashboard();
      });
    } catch (error) {
      if (!mounted) return;
      _toast(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _selling = false);
    }
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
        actions: [IconButton(tooltip: 'Refresh', onPressed: _reload, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: FutureBuilder<_MerchantSellerDashboard>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF251538)));
          if (snapshot.hasError) return _ErrorState(message: snapshot.error.toString(), onRetry: _reload);
          final dashboard = snapshot.data;
          if (dashboard == null) return _ErrorState(message: 'Panel data is empty.', onRetry: _reload);

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            color: const Color(0xFF251538),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              children: [
                _HeaderCard(userName: dashboard.userName, personalCoins: dashboard.personalCoins),
                const SizedBox(height: 14),
                _SectionTitle(title: 'Supply Pools', subtitle: 'Real /coin-sales/my-supply-pools balances'),
                const SizedBox(height: 10),
                if (dashboard.pools.isEmpty)
                  const _EmptyPoolCard()
                else
                  ...dashboard.pools.map(
                    (pool) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PoolCard(
                        pool: pool,
                        selected: _selectedPoolId == pool.id,
                        onTap: () => setState(() => _selectedPoolId = pool.id),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                _SectionTitle(title: 'Sell Coins to User', subtitle: 'Real POST /coin-sales/sell-to-user'),
                const SizedBox(height: 10),
                _SaleForm(
                  buyerIdController: _buyerIdController,
                  coinAmountController: _coinAmountController,
                  paymentAmountController: _paymentAmountController,
                  reasonController: _reasonController,
                  selling: _selling,
                  onSell: _sellCoins,
                ),
                const SizedBox(height: 14),
                const _RuleCard(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MerchantSellerDashboard {
  const _MerchantSellerDashboard({required this.userName, required this.personalCoins, required this.pools});

  final String userName;
  final int personalCoins;
  final List<CoinSupplyPoolSummary> pools;
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.userName, required this.personalCoins});

  final String userName;
  final int personalCoins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF251538), Color(0xFF4A2A63)]), borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.16), blurRadius: 18, offset: const Offset(0, 8))]),
      child: Row(
        children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.storefront_rounded, color: Color(0xFFFFD36A))),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Personal wallet: ${_formatNumber(personalCoins)} coins', style: TextStyle(color: Colors.white.withValues(alpha: 0.76), fontSize: 12.5, fontWeight: FontWeight.w800)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _PoolCard extends StatelessWidget {
  const _PoolCard({required this.pool, required this.selected, required this.onTap});

  final CoinSupplyPoolSummary pool;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (pool.poolType) {
      'MERCHANT_SUPPLY_POOL' => const Color(0xFF6D5DF6),
      'OWNER_SUPPLY_POOL' => const Color(0xFFC99A3B),
      'FOUNDER_MINT_POOL' => const Color(0xFFE84C72),
      _ => const Color(0xFF12C7B7),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: selected ? color : const Color(0xFFECE2D8), width: selected ? 1.6 : 1)),
        child: Row(
          children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(17)), child: Icon(Icons.account_balance_wallet_rounded, color: color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pool.poolType.replaceAll('_', ' '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 14.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('Pool #${pool.id} • ${pool.status}', style: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 11.5, fontWeight: FontWeight.w700)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_formatNumber(pool.balance), style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
              const Text('available', style: TextStyle(color: Color(0xFF8C7B8F), fontSize: 10, fontWeight: FontWeight.w800)),
              if (selected) Icon(Icons.check_circle_rounded, color: color, size: 18),
            ]),
          ],
        ),
      ),
    );
  }
}

class _SaleForm extends StatelessWidget {
  const _SaleForm({required this.buyerIdController, required this.coinAmountController, required this.paymentAmountController, required this.reasonController, required this.selling, required this.onSell});

  final TextEditingController buyerIdController;
  final TextEditingController coinAmountController;
  final TextEditingController paymentAmountController;
  final TextEditingController reasonController;
  final bool selling;
  final VoidCallback onSell;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Column(
        children: [
          _Input(controller: buyerIdController, label: 'Buyer public user ID', icon: Icons.badge_rounded, keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          _Input(controller: coinAmountController, label: 'Coin amount', icon: Icons.monetization_on_rounded, keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          _Input(controller: paymentAmountController, label: 'Payment amount recorded, INR', icon: Icons.currency_rupee_rounded, keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          _Input(controller: reasonController, label: 'Reason / note', icon: Icons.note_alt_rounded),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: selling ? null : onSell,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF251538), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              icon: selling ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
              label: Text(selling ? 'Sending...' : 'Sell / Send Coins', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({required this.controller, required this.label, required this.icon, this.keyboardType});

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFF251538), fontSize: 13.5, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 12, fontWeight: FontWeight.w700),
        prefixIcon: Icon(icon, color: const Color(0xFF6D5DF6), size: 19),
        filled: true,
        fillColor: const Color(0xFFFAF7F1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: Color(0xFF12C7B7), width: 1.4)),
      ),
    );
  }
}

class _EmptyPoolCard extends StatelessWidget {
  const _EmptyPoolCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFECE2D8))),
      child: const Text('No seller/merchant supply pool is available for this account yet. Ask Owner/Super Owner to grant supply first.', style: TextStyle(color: Color(0xFF8C7B8F), fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.3)),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard();

  @override
  Widget build(BuildContext context) {
    const rules = ['Seller supply pool decreases when coins are sent.', 'Buyer wallet increases immediately after successful delivery.', 'Personal wallet coins are separate from merchant/seller inventory.', 'Every sale is recorded server-side with pool ledger and wallet ledger.'];
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Column(children: [for (final rule in rules) Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle_rounded, color: Color(0xFF12C7B7), size: 18), const SizedBox(width: 8), Expanded(child: Text(rule, style: const TextStyle(color: Color(0xFF251538), fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.25)))]))]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFE84C72), size: 38),
            const SizedBox(height: 10),
            const Text('Could not load panel', style: TextStyle(color: Color(0xFF251538), fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF251538), foregroundColor: Colors.white)),
          ]),
        ),
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

String _formatNumber(int value) {
  final sign = value < 0 ? '-' : '';
  final raw = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    final reverseIndex = raw.length - index;
    buffer.write(raw[index]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) buffer.write(',');
  }
  return '$sign$buffer';
}
