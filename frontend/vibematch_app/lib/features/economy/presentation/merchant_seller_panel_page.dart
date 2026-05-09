import 'package:flutter/material.dart';

class MerchantSellerPanelPage extends StatelessWidget {
  const MerchantSellerPanelPage({super.key});

  static const int personalCoins = 12840;
  static const int rubies = 3820;
  static const int sellerPoolCoins = 500000;
  static const int merchantPoolCoins = 1200000;
  static const int gamingPoolCoins = 250000;

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
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: [
          _InfoBanner(
            title: 'Pool coins are inventory only',
            body: 'Seller, merchant, sub-owner and gaming pool coins are never shown inside normal coin balance and cannot be used directly for gifts, games, store items or personal spending.',
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              Expanded(child: _WalletCard(title: 'Personal Coins', value: personalCoins, icon: Icons.monetization_on_rounded, color: Color(0xFFC99A3B), note: 'Spendable by this account')),
              SizedBox(width: 12),
              Expanded(child: _WalletCard(title: 'Rubies', value: rubies, icon: Icons.diamond_rounded, color: Color(0xFFE84C72), note: 'Earned / withdrawable')),
            ],
          ),
          const SizedBox(height: 14),
          _SectionTitle(title: 'Supply Pools', subtitle: 'Inventory balances, separated from personal wallet'),
          const SizedBox(height: 10),
          _PoolCard(
            title: 'Seller Supply Pool',
            value: sellerPoolCoins,
            icon: Icons.storefront_rounded,
            color: const Color(0xFF12C7B7),
            subtitle: 'Can sell coins to users through official sale flow only.',
            actions: [
              _PanelAction(label: 'Sell Coins', icon: Icons.person_add_alt_1_rounded, onTap: () => _showAction(context, 'Seller coin sale form will open.')),
              _PanelAction(label: 'Sale Logs', icon: Icons.receipt_long_rounded, onTap: () => _showAction(context, 'Seller sale ledger will open.')),
            ],
          ),
          const SizedBox(height: 12),
          _PoolCard(
            title: 'Merchant Supply Pool',
            value: merchantPoolCoins,
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFF6D5DF6),
            subtitle: 'Can distribute to sellers or sell directly when permission allows.',
            actions: [
              _PanelAction(label: 'Allocate', icon: Icons.call_split_rounded, onTap: () => _showAction(context, 'Merchant allocation flow will open.')),
              _PanelAction(label: 'Ledger', icon: Icons.history_rounded, onTap: () => _showAction(context, 'Merchant pool ledger will open.')),
            ],
          ),
          const SizedBox(height: 12),
          _PoolCard(
            title: 'Gaming Pool',
            value: gamingPoolCoins,
            icon: Icons.sports_esports_rounded,
            color: const Color(0xFFE84C72),
            subtitle: 'Separate game liquidity/risk pool. Game winnings pay coins only; games do not mint rubies.',
            actions: [
              _PanelAction(label: 'Game Pools', icon: Icons.casino_rounded, onTap: () => _showAction(context, 'Game pool dashboard will open.')),
              _PanelAction(label: 'Risk Logs', icon: Icons.shield_rounded, onTap: () => _showAction(context, 'Gaming risk logs will open.')),
            ],
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Economy Rules', subtitle: 'Backend source of truth'),
          const SizedBox(height: 10),
          const _RuleList(),
        ],
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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.lock_rounded, color: Color(0xFFFFD36A)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(body, style: TextStyle(color: Colors.white.withValues(alpha: 0.76), fontSize: 12.5, height: 1.28, fontWeight: FontWeight.w700)),
              ],
            ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 10),
          Text(value.toString(), style: const TextStyle(color: Color(0xFF251538), fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(note, style: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 10.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PoolCard extends StatelessWidget {
  const _PoolCard({required this.title, required this.value, required this.icon, required this.color, required this.subtitle, required this.actions});

  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final String subtitle;
  final List<_PanelAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)), child: Icon(icon, color: color)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 16, fontWeight: FontWeight.w900)),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 11.5, height: 1.25, fontWeight: FontWeight.w700)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(value.toString(), style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.w900)),
                const Text('pool coins', style: TextStyle(color: Color(0xFF8C7B8F), fontSize: 10, fontWeight: FontWeight.w800)),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            for (var index = 0; index < actions.length; index++) ...[
              Expanded(child: actions[index]),
              if (index != actions.length - 1) const SizedBox(width: 10),
            ],
          ]),
        ],
      ),
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
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: const Color(0xFF251538), size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Color(0xFF251538), fontSize: 12, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 21, fontWeight: FontWeight.w900)),
      const SizedBox(height: 3),
      Text(subtitle, style: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 12, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _RuleList extends StatelessWidget {
  const _RuleList();

  @override
  Widget build(BuildContext context) {
    const rules = [
      'Coins are spendable app currency.',
      'Rubies are earned from receiving gifts and are withdrawable after review.',
      '100 received coins = 30 rubies by default.',
      'Seller and merchant pool coins are supply inventory, not normal balance.',
      'Gaming pools are separate from social gifts and pay coins only.',
    ];

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Column(
        children: [
          for (final rule in rules) Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF12C7B7), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(rule, style: const TextStyle(color: Color(0xFF251538), fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.25))),
            ]),
          ),
        ],
      ),
    );
  }
}
