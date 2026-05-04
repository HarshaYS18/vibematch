import 'package:flutter/material.dart';

import '../data/wallet_mock_data.dart';
import '../models/wallet_models.dart';
import 'wallet_shared_widgets.dart';

class PaymentMethodSheet extends StatelessWidget {
  const PaymentMethodSheet({super.key, required this.package, required this.onMethodSelected});

  final CoinPackage package;
  final ValueChanged<String> onMethodSelected;

  @override
  Widget build(BuildContext context) {
    return WalletDarkSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WalletSheetHandle(),
          const SizedBox(height: 16),
          const Text('Select Payment Method', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${package.coinsText} coins • ${package.priceText}', style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _PaymentMethodTile(icon: Icons.account_balance_rounded, title: 'UPI', subtitle: 'Pay with any UPI app', onTap: () => onMethodSelected('UPI')),
          const SizedBox(height: 10),
          _PaymentMethodTile(icon: Icons.payments_rounded, title: 'G Pay', subtitle: 'Pay with Google Pay', onTap: () => onMethodSelected('G Pay')),
        ],
      ),
    );
  }
}

class CoinHistorySheet extends StatefulWidget {
  const CoinHistorySheet({super.key});

  @override
  State<CoinHistorySheet> createState() => _CoinHistorySheetState();
}

class _CoinHistorySheetState extends State<CoinHistorySheet> {
  CoinHistoryTab _selectedTab = CoinHistoryTab.income;

  @override
  Widget build(BuildContext context) {
    final rows = walletCoinHistoryRows[_selectedTab] ?? const <WalletHistoryRow>[];

    return WalletDarkSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WalletSheetHandle(),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Coin History', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 12),
          Row(
            children: CoinHistoryTab.values.map((tab) {
              return Expanded(child: _DarkTab(label: tab.label, selected: _selectedTab == tab, onTap: () => setState(() => _selectedTab = tab)));
            }).toList(),
          ),
          const SizedBox(height: 12),
          ...rows.map((row) => WalletHistoryTile(row: row)),
        ],
      ),
    );
  }
}

class WithdrawHistorySheet extends StatelessWidget {
  const WithdrawHistorySheet({super.key});

  @override
  Widget build(BuildContext context) {
    return WalletDarkSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WalletSheetHandle(),
          const SizedBox(height: 16),
          const Text('Withdraw History', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          const _WithdrawStatusFlow(activeIndex: 2),
          const SizedBox(height: 14),
          ...walletWithdrawHistoryRows.map((row) => WalletHistoryTile(row: row)),
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                    Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkTab extends StatelessWidget {
  const _DarkTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: selected ? WalletColors.aqua : Colors.white.withValues(alpha: 0.08)),
        child: Text(label, style: TextStyle(color: selected ? const Color(0xFF12101D) : Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _WithdrawStatusFlow extends StatelessWidget {
  const _WithdrawStatusFlow({required this.activeIndex});

  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(walletWithdrawStatusSteps.length, (index) {
        final active = index <= activeIndex;
        return Expanded(
          child: Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(shape: BoxShape.circle, color: active ? WalletColors.aqua : Colors.white12),
                child: Icon(active ? Icons.check_rounded : Icons.circle, size: 13, color: Colors.white),
              ),
              const SizedBox(height: 5),
              Text(walletWithdrawStatusSteps[index], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? Colors.white : Colors.white38, fontSize: 9, fontWeight: FontWeight.w800)),
            ],
          ),
        );
      }),
    );
  }
}
