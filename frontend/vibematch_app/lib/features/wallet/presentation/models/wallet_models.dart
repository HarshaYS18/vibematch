import 'package:flutter/material.dart';

enum WalletSection {
  coins(label: 'Coins', icon: Icons.monetization_on_rounded),
  ruby(label: 'Ruby', icon: Icons.diamond_rounded);

  const WalletSection({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class CoinPackage {
  const CoinPackage({required this.coins, required this.priceInr, this.badge});

  final int coins;
  final int priceInr;
  final String? badge;

  String get coinsText => formatWalletNumber(coins);
  String get priceText => '₹$priceInr';
}

enum CoinHistoryTab { income, spent, recharge }

extension CoinHistoryTabLabel on CoinHistoryTab {
  String get label {
    switch (this) {
      case CoinHistoryTab.income:
        return 'Income';
      case CoinHistoryTab.spent:
        return 'Spent';
      case CoinHistoryTab.recharge:
        return 'Recharge';
    }
  }
}

class WalletHistoryRow {
  const WalletHistoryRow({required this.title, required this.subtitle, required this.amount});

  final String title;
  final String subtitle;
  final String amount;
}

String formatWalletNumber(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final remaining = raw.length - i;
    buffer.write(raw[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

String withdrawAmountForCoins(int coins) {
  final rupees = coins * 40 / 10000;
  return rupees % 1 == 0 ? '₹${rupees.toInt()}' : '₹${rupees.toStringAsFixed(2)}';
}
