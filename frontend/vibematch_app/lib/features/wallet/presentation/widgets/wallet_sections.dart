import 'package:flutter/material.dart';

import '../data/wallet_mock_data.dart';
import '../models/wallet_models.dart';
import 'wallet_shared_widgets.dart';

class WalletSectionTabs extends StatelessWidget {
  const WalletSectionTabs({super.key, required this.selectedSection, required this.onChanged});

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

class WalletOverviewCard extends StatelessWidget {
  const WalletOverviewCard({super.key, required this.selectedSection, required this.onPrimaryTap, required this.onHistoryTap});

  final WalletSection selectedSection;
  final VoidCallback onPrimaryTap;
  final VoidCallback onHistoryTap;

  @override
  Widget build(BuildContext context) {
    final isCoins = selectedSection == WalletSection.coins;
    final title = isCoins ? 'Coin Balance' : 'Ruby Balance';
    final value = isCoins ? '35,494' : '8,260';
    final subtitle = isCoins ? 'Recharge, gifts, Lucky Packet, store and games' : 'Convert Ruby to coins or apply for withdrawal';
    final icon = isCoins ? Icons.monetization_on_rounded : Icons.diamond_rounded;
    final colors = isCoins
        ? const [Color(0xFFFFD166), Color(0xFFE84C72), Color(0xFF6D5DF6)]
        : const [Color(0xFFE84C72), Color(0xFF8C5CF6), Color(0xFF12C7B7)];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.24), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.18), border: Border.all(color: Colors.white.withValues(alpha: 0.24))),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: WalletPrimaryButton(label: isCoins ? 'Recharge' : 'Ruby Actions', icon: isCoins ? Icons.add_circle_rounded : Icons.swap_horiz_rounded, onTap: onPrimaryTap)),
              const SizedBox(width: 10),
              Expanded(child: WalletGhostButton(label: isCoins ? 'Coin History' : 'Withdraw History', icon: Icons.receipt_long_rounded, onTap: onHistoryTap)),
            ],
          ),
        ],
      ),
    );
  }
}

class WalletCoinsSection extends StatelessWidget {
  const WalletCoinsSection({super.key, required this.onPackageTap, required this.onHistoryTap});

  final ValueChanged<CoinPackage> onPackageTap;
  final VoidCallback onHistoryTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        WalletInfoCard(
          title: 'Coins',
          subtitle: 'Used for gifts, Lucky Packet, store purchases, and coin games.',
          icon: Icons.monetization_on_rounded,
          accent: WalletColors.gold,
          trailing: WalletMiniActionChip(icon: Icons.history_rounded, label: 'History', onTap: onHistoryTap),
          rows: const [
            WalletInfoRow(label: 'Coin balance', value: '35,494'),
            WalletInfoRow(label: 'Base pack', value: '20,000 coins / ₹120'),
            WalletInfoRow(label: 'Payment methods', value: 'UPI, GPay'),
          ],
        ),
        const SizedBox(height: 12),
        WalletCoinPackageList(onPackageTap: onPackageTap),
      ],
    );
  }
}

class WalletCoinPackageList extends StatelessWidget {
  const WalletCoinPackageList({super.key, required this.onPackageTap});

  final ValueChanged<CoinPackage> onPackageTap;

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
              Expanded(child: Text('Coin Recharge Packs', style: TextStyle(color: WalletColors.deep, fontSize: 16, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Tap a pack to choose UPI or GPay.', style: TextStyle(color: Color(0xFF6F627A), fontSize: 11.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: walletCoinPackages.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.42),
            itemBuilder: (context, index) {
              final package = walletCoinPackages[index];
              return _CoinPackageCard(package: package, onTap: () => onPackageTap(package));
            },
          ),
        ],
      ),
    );
  }
}

class WalletRubySection extends StatefulWidget {
  const WalletRubySection({super.key, required this.onWithdrawHistoryTap, required this.onToast});

  final VoidCallback onWithdrawHistoryTap;
  final ValueChanged<String> onToast;

  @override
  State<WalletRubySection> createState() => _WalletRubySectionState();
}

class _WalletRubySectionState extends State<WalletRubySection> {
  final TextEditingController _convertController = TextEditingController(text: '30');
  final TextEditingController _withdrawController = TextEditingController(text: '10000');

  int get _convertRubies => int.tryParse(_convertController.text.trim()) ?? 0;
  int get _withdrawCoins => int.tryParse(_withdrawController.text.trim()) ?? 0;

  @override
  void dispose() {
    _convertController.dispose();
    _withdrawController.dispose();
    super.dispose();
  }

  void _convertRubiesToCoins() {
    if (_convertRubies <= 0) {
      widget.onToast('Enter valid Ruby amount');
      return;
    }
    widget.onToast('$_convertRubies Ruby converted to $_convertRubies Coins');
  }

  void _applyWithdraw() {
    if (_withdrawCoins < 10000) {
      widget.onToast('Minimum withdrawal is 10,000 coins');
      return;
    }
    widget.onToast('Withdrawal applied for ${formatWalletNumber(_withdrawCoins)} coins (${withdrawAmountForCoins(_withdrawCoins)})');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        WalletInfoCard(
          title: 'Ruby',
          subtitle: 'Convert Ruby to coins or withdraw eligible coin value.',
          icon: Icons.diamond_rounded,
          accent: WalletColors.coral,
          trailing: WalletMiniActionChip(icon: Icons.account_balance_wallet_rounded, label: 'Withdraw History', onTap: widget.onWithdrawHistoryTap),
          rows: const [
            WalletInfoRow(label: 'Ruby balance', value: '8,260'),
            WalletInfoRow(label: 'Coin balance', value: '35,494'),
            WalletInfoRow(label: 'Withdraw minimum', value: '10,000 coins'),
          ],
        ),
        const SizedBox(height: 12),
        _RubyInputCard(
          title: 'Convert Ruby to Coins',
          subtitle: 'Enter rubies to convert.',
          controller: _convertController,
          icon: Icons.swap_horiz_rounded,
          preview: '${formatWalletNumber(_convertRubies)} Coins',
          buttonText: 'Convert',
          onChanged: () => setState(() {}),
          onTap: _convertRubiesToCoins,
        ),
        const SizedBox(height: 12),
        _RubyInputCard(
          title: 'Withdraw Coins',
          subtitle: 'Minimum 10,000 coins. 10,000 coins = ₹40.',
          controller: _withdrawController,
          icon: Icons.payments_rounded,
          preview: _withdrawCoins < 10000 ? 'Minimum 10,000 coins' : withdrawAmountForCoins(_withdrawCoins),
          buttonText: 'Apply Withdraw',
          onChanged: () => setState(() {}),
          onTap: _applyWithdraw,
        ),
      ],
    );
  }
}

class _CoinPackageCard extends StatelessWidget {
  const _CoinPackageCard({required this.package, required this.onTap});

  final CoinPackage package;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badge = package.badge;
    return Material(
      color: WalletColors.bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: WalletColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [Color(0xFFFFD166), WalletColors.gold]),
                      boxShadow: [BoxShadow(color: WalletColors.gold.withValues(alpha: 0.20), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 17),
                  ),
                  const Spacer(),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(color: WalletColors.coral.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(999)),
                      child: Text(badge, style: const TextStyle(color: WalletColors.coral, fontSize: 8.5, fontWeight: FontWeight.w900)),
                    ),
                ],
              ),
              const Spacer(),
              Text('${package.coinsText} coins', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: WalletColors.deep, fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(package.priceText, style: const TextStyle(color: WalletColors.gold, fontSize: 13, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RubyInputCard extends StatelessWidget {
  const _RubyInputCard({required this.title, required this.subtitle, required this.controller, required this.icon, required this.preview, required this.buttonText, required this.onChanged, required this.onTap});

  final String title;
  final String subtitle;
  final TextEditingController controller;
  final IconData icon;
  final String preview;
  final String buttonText;
  final VoidCallback onChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WalletWhiteCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: WalletColors.coral, size: 21), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(color: WalletColors.deep, fontSize: 16, fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF6F627A), fontSize: 11.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              filled: true,
              fillColor: WalletColors.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: WalletColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: WalletColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: WalletColors.coral)),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: Text(preview, style: const TextStyle(color: WalletColors.deep, fontSize: 13, fontWeight: FontWeight.w900))), WalletPrimarySmallButton(text: buttonText, onTap: onTap)]),
        ],
      ),
    );
  }
}
