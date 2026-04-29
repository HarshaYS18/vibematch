import 'package:flutter/material.dart';

import '../../../core/presentation/vm_skeleton_page.dart';

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VmSkeletonPage(
      title: 'Wallet',
      subtitle: 'Coins, recharge, gift spending, transaction history, and payout-safe accounting will live here.',
      icon: Icons.account_balance_wallet_rounded,
      highlights: [
        'Coin balance and recharge entry point.',
        'Transaction ledger for gifts, store, games, and admin adjustments.',
        'Future backend: wallet and wallet_transactions APIs.',
      ],
    );
  }
}
