import '../models/wallet_models.dart';

const List<CoinPackage> walletCoinPackages = [
  CoinPackage(coins: 20000, priceInr: 120, badge: 'Starter'),
  CoinPackage(coins: 50000, priceInr: 300),
  CoinPackage(coins: 100000, priceInr: 600, badge: 'Popular'),
  CoinPackage(coins: 250000, priceInr: 1500),
  CoinPackage(coins: 500000, priceInr: 3000, badge: 'Best Value'),
  CoinPackage(coins: 1000000, priceInr: 6000, badge: 'Max'),
];

const Map<CoinHistoryTab, List<WalletHistoryRow>> walletCoinHistoryRows = {
  CoinHistoryTab.income: [
    WalletHistoryRow(title: 'Gift received', subtitle: 'Late Night Chill', amount: '+4,500'),
    WalletHistoryRow(title: 'Lucky Packet reward', subtitle: 'Room packet', amount: '+220'),
  ],
  CoinHistoryTab.spent: [
    WalletHistoryRow(title: 'Gift sent', subtitle: 'Love Rocket x9', amount: '-1,800'),
    WalletHistoryRow(title: 'Lucky Packet sent', subtitle: '5 people', amount: '-500'),
  ],
  CoinHistoryTab.recharge: [
    WalletHistoryRow(title: 'Recharge successful', subtitle: 'UPI • ₹120', amount: '+20,000'),
    WalletHistoryRow(title: 'Recharge pending', subtitle: 'G Pay • ₹600', amount: '+100,000'),
  ],
};

const List<String> walletWithdrawStatusSteps = [
  'Applied',
  'Review',
  'Approved',
  'Processing',
  'Successful',
];

const List<WalletHistoryRow> walletWithdrawHistoryRows = [
  WalletHistoryRow(title: 'Current withdrawal', subtitle: '25,000 coins • ₹100', amount: 'Approved'),
  WalletHistoryRow(title: 'Withdrawal successful', subtitle: '10,000 coins • ₹40', amount: 'Successful'),
  WalletHistoryRow(title: 'Withdrawal processing', subtitle: '50,000 coins • ₹200', amount: 'Processing'),
];
