import 'package:flutter/material.dart';

import '../../data/coin_sales_api_service.dart';

class CoinSupplyGrantPage extends StatefulWidget {
  const CoinSupplyGrantPage({super.key});

  @override
  State<CoinSupplyGrantPage> createState() => _CoinSupplyGrantPageState();
}

class _CoinSupplyGrantPageState extends State<CoinSupplyGrantPage> {
  final CoinSalesApiService _api = const CoinSalesApiService();
  final TextEditingController _targetPublicIdController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(text: '100000');
  final TextEditingController _reasonController = TextEditingController(text: 'Owner grants seller/merchant testing supply');

  String _poolType = 'SELLER_SUPPLY_POOL';
  bool _busy = false;
  CoinSupplyPoolSummary? _lastPool;

  static const List<String> _poolTypes = <String>[
    'SELLER_SUPPLY_POOL',
    'MERCHANT_SUPPLY_POOL',
    'OWNER_SUPPLY_POOL',
  ];

  @override
  void dispose() {
    _targetPublicIdController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538)));
  }

  Future<void> _grantSupply() async {
    final targetPublicId = int.tryParse(_targetPublicIdController.text.trim());
    final amount = int.tryParse(_amountController.text.trim());
    final reason = _reasonController.text.trim();

    if (targetPublicId == null || targetPublicId <= 0) {
      _toast('Enter valid target public user ID.');
      return;
    }
    if (amount == null || amount <= 0) {
      _toast('Enter valid supply amount.');
      return;
    }
    if (reason.length < 3) {
      _toast('Enter audit reason.');
      return;
    }
    if (_busy) return;

    setState(() => _busy = true);
    try {
      final pool = await _api.grantSupply(
        targetPublicUserId: targetPublicId,
        poolType: _poolType,
        amount: amount,
        reason: reason,
      );
      if (!mounted) return;
      setState(() => _lastPool = pool);
      _toast('Supply granted. New pool balance: ${_formatNumber(pool.balance)}');
    } catch (error) {
      if (!mounted) return;
      _toast(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastPool = _lastPool;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFAF7F1),
        foregroundColor: const Color(0xFF251538),
        title: const Text('Grant Coin Supply', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF251538)))),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: [
          const _HeaderCard(),
          const SizedBox(height: 14),
          _Card(
            child: Column(
              children: [
                _Input(controller: _targetPublicIdController, label: 'Target public user ID', icon: Icons.badge_rounded, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _poolType,
                  items: _poolTypes.map((item) => DropdownMenuItem<String>(value: item, child: Text(item.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w800)))).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _poolType = value);
                  },
                  decoration: _inputDecoration(label: 'Supply pool type', icon: Icons.account_balance_wallet_rounded),
                ),
                const SizedBox(height: 12),
                _Input(controller: _amountController, label: 'Amount to grant', icon: Icons.monetization_on_rounded, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _Input(controller: _reasonController, label: 'Reason / audit note', icon: Icons.note_alt_rounded),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _grantSupply,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF251538), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                    icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add_circle_rounded),
                    label: Text(_busy ? 'Granting...' : 'Grant Supply', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
          if (lastPool != null) ...[
            const SizedBox(height: 14),
            _ResultCard(pool: lastPool),
          ],
          const SizedBox(height: 14),
          const _RuleCard(),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF251538), Color(0xFF4A2A63)]), borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.16), blurRadius: 18, offset: const Offset(0, 8))]),
      child: Row(children: [
        Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.account_balance_rounded, color: Color(0xFFFFD36A))),
        const SizedBox(width: 13),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Owner Supply Grant', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          SizedBox(height: 4),
          Text('Grant pool inventory to sellers, merchants, or owners using real backend ledger flow.', style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.25)),
        ])),
      ]),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.pool});

  final CoinSupplyPoolSummary pool;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Last Grant Result', style: TextStyle(color: Color(0xFF251538), fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        _Line(label: 'Pool ID', value: '#${pool.id}'),
        _Line(label: 'Pool Type', value: pool.poolType),
        _Line(label: 'Balance', value: _formatNumber(pool.balance)),
        _Line(label: 'Reserved', value: _formatNumber(pool.reservedBalance)),
        _Line(label: 'Status', value: pool.status),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 12, fontWeight: FontWeight.w800))),
        Text(value, style: const TextStyle(color: Color(0xFF251538), fontSize: 12.5, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFFECE2D8))), child: child);
}

class _Input extends StatelessWidget {
  const _Input({required this.controller, required this.label, required this.icon, this.keyboardType});

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => TextField(controller: controller, keyboardType: keyboardType, style: const TextStyle(color: Color(0xFF251538), fontSize: 13.5, fontWeight: FontWeight.w800), decoration: _inputDecoration(label: label, icon: icon));
}

InputDecoration _inputDecoration({required String label, required IconData icon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 12, fontWeight: FontWeight.w700),
    prefixIcon: Icon(icon, color: const Color(0xFF6D5DF6), size: 19),
    filled: true,
    fillColor: const Color(0xFFFAF7F1),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: Color(0xFF12C7B7), width: 1.4)),
  );
}

class _RuleCard extends StatelessWidget {
  const _RuleCard();

  @override
  Widget build(BuildContext context) {
    const rules = ['Only Owner/Super Owner should access this backend endpoint.', 'Supply pool balance is inventory, not user spendable wallet.', 'Seller/Merchant can sell from supply pool to a normal user wallet.', 'Every grant is backend-recorded for ledger/audit review.'];
    return _Card(child: Column(children: [for (final rule in rules) Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle_rounded, color: Color(0xFF12C7B7), size: 18), const SizedBox(width: 8), Expanded(child: Text(rule, style: const TextStyle(color: Color(0xFF251538), fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.25)))]))]));
  }
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
