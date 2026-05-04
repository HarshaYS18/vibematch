import 'package:flutter/material.dart';

import 'models/wallet_models.dart';
import 'widgets/wallet_sections.dart';
import 'widgets/wallet_shared_widgets.dart';
import 'widgets/wallet_sheets.dart';

class WalletPageModular extends StatefulWidget {
  const WalletPageModular({super.key});

  @override
  State<WalletPageModular> createState() => _WalletPageModularState();
}

class _WalletPageModularState extends State<WalletPageModular> {
  WalletSection _selectedSection = WalletSection.coins;

  void _showToast(String message) {
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

  void _openPaymentMethodSheet(CoinPackage package) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentMethodSheet(
        package: package,
        onMethodSelected: (method) {
          Navigator.pop(context);
          _showToast('$method selected for ${package.coinsText} coins');
        },
      ),
    );
  }

  void _openCoinHistorySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CoinHistorySheet(),
    );
  }

  void _openWithdrawHistorySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WithdrawHistorySheet(),
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
              boxShadow: [BoxShadow(color: WalletColors.deep.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 7))],
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
                      Text('Wallet', style: TextStyle(color: WalletColors.deep, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.7)),
                      SizedBox(height: 2),
                      Text('Coins and Ruby balances', style: TextStyle(color: WalletColors.plum, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                WalletHeaderIconButton(
                  icon: Icons.receipt_long_rounded,
                  onTap: _selectedSection == WalletSection.coins ? _openCoinHistorySheet : _openWithdrawHistorySheet,
                ),
                const SizedBox(width: 8),
                WalletHeaderIconButton(icon: Icons.support_agent_rounded, onTap: () => _showToast('Wallet support opened')),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                WalletOverviewCard(
                  selectedSection: _selectedSection,
                  onPrimaryTap: () {
                    if (_selectedSection == WalletSection.coins) {
                      _showToast('Select a coin pack below');
                    } else {
                      _showToast('Enter Ruby amount below');
                    }
                  },
                  onHistoryTap: _selectedSection == WalletSection.coins ? _openCoinHistorySheet : _openWithdrawHistorySheet,
                ),
                const SizedBox(height: 14),
                WalletSectionTabs(selectedSection: _selectedSection, onChanged: (section) => setState(() => _selectedSection = section)),
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  child: _selectedSection == WalletSection.coins
                      ? WalletCoinsSection(
                          key: const ValueKey('coins'),
                          onPackageTap: _openPaymentMethodSheet,
                          onHistoryTap: _openCoinHistorySheet,
                        )
                      : WalletRubySection(
                          key: const ValueKey('ruby'),
                          onWithdrawHistoryTap: _openWithdrawHistorySheet,
                          onToast: _showToast,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
