import 'package:flutter/material.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  static const Color _bg = Color(0xFFFAF7F1);
  static const Color _deep = Color(0xFF251538);
  static const Color _plum = Color(0xFF4A2A63);
  static const Color _aqua = Color(0xFF12C7B7);
  static const Color _violet = Color(0xFF6D5DF6);
  static const Color _coral = Color(0xFFE84C72);
  static const Color _gold = Color(0xFFC99A3B);
  static const Color _softBorder = Color(0xFFECE2D8);

  WalletSection _selectedSection = WalletSection.coins;

  void _showMockToast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _deep,
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
  }

  void _openPaymentMethodSheet(CoinPackage package) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentMethodSheet(
        package: package,
        onMethodSelected: (method) {
          Navigator.pop(context);
          _showMockToast('$method payment selected for ${package.coinsText} coins');
        },
      ),
    );
  }

  void _openRubyConvertSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _RubyConvertSheet(
        onConvert: () {
          Navigator.pop(context);
          _showMockToast('30 Ruby converted to 30 Coins');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              border: const Border(bottom: BorderSide(color: _softBorder)),
              boxShadow: [
                BoxShadow(
                  color: _deep.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: _deep),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wallet',
                        style: TextStyle(color: _deep, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.7),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Coins and Ruby balances',
                        style: TextStyle(color: _plum, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                _HeaderIconButton(
                  icon: Icons.receipt_long_rounded,
                  onTap: () => _showMockToast('Wallet transaction history opened'),
                ),
                const SizedBox(width: 8),
                _HeaderIconButton(
                  icon: Icons.support_agent_rounded,
                  onTap: () => _showMockToast('Wallet support opened'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _WalletOverviewCard(
                  selectedSection: _selectedSection,
                  onRechargeTap: () {
                    if (_selectedSection == WalletSection.coins) {
                      _showMockToast('Select a coin pack below');
                    } else {
                      _openRubyConvertSheet();
                    }
                  },
                  onHistoryTap: () => _showMockToast('Transaction history opened'),
                ),
                const SizedBox(height: 14),
                _WalletSectionTabs(
                  selectedSection: _selectedSection,
                  onChanged: (section) => setState(() => _selectedSection = section),
                ),
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  child: _selectedSection == WalletSection.coins
                      ? _CoinsSection(
                          key: const ValueKey('coins'),
                          onPackageTap: _openPaymentMethodSheet,
                          onSendGiftTap: () => _showMockToast('Gift section opened'),
                          onLuckyPacketTap: () => _showMockToast('Lucky Packet wallet ledger opened'),
                          onGameCoinsTap: () => _showMockToast('Coin games wallet controls opened'),
                        )
                      : _RubySection(
                          key: const ValueKey('ruby'),
                          onConvertTap: _openRubyConvertSheet,
                          onEarningsTap: () => _showMockToast('Ruby earnings opened'),
                          onPayoutTap: () => _showMockToast('Ruby payout request opened'),
                          onRulesTap: () => _showMockToast('Ruby rules opened'),
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

  String get coinsText => _formatNumber(coins);
  String get priceText => '₹$priceInr';

  static String _formatNumber(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final remaining = raw.length - i;
      buffer.write(raw[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
    }
    return buffer.toString();
  }
}

const List<CoinPackage> _coinPackages = [
  CoinPackage(coins: 20000, priceInr: 120, badge: 'Starter'),
  CoinPackage(coins: 50000, priceInr: 300),
  CoinPackage(coins: 100000, priceInr: 600, badge: 'Popular'),
  CoinPackage(coins: 250000, priceInr: 1500),
  CoinPackage(coins: 500000, priceInr: 3000, badge: 'Best Value'),
  CoinPackage(coins: 1000000, priceInr: 6000, badge: 'Max'),
];

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFAF7F1),
            border: Border.all(color: const Color(0xFFECE2D8)),
          ),
          child: Icon(icon, color: const Color(0xFF251538), size: 19),
        ),
      ),
    );
  }
}

class _WalletOverviewCard extends StatelessWidget {
  const _WalletOverviewCard({
    required this.selectedSection,
    required this.onRechargeTap,
    required this.onHistoryTap,
  });

  final WalletSection selectedSection;
  final VoidCallback onRechargeTap;
  final VoidCallback onHistoryTap;

  @override
  Widget build(BuildContext context) {
    final isCoins = selectedSection == WalletSection.coins;
    final title = isCoins ? 'Coin Balance' : 'Ruby Balance';
    final value = isCoins ? '35,494' : '8,260';
    final subtitle = isCoins ? 'For gifts, Lucky Packet, store and games' : '30% of gift coins received becomes Ruby';
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
              Expanded(
                child: _WalletPrimaryButton(
                  label: isCoins ? 'Recharge' : 'Convert Ruby',
                  icon: isCoins ? Icons.add_circle_rounded : Icons.swap_horiz_rounded,
                  onTap: onRechargeTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WalletGhostButton(
                  label: 'History',
                  icon: Icons.receipt_long_rounded,
                  onTap: onHistoryTap,
                ),
              ),
            ],
          ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFECE2D8)),
      ),
      child: Row(
        children: WalletSection.values.map((section) {
          final selected = section == selectedSection;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(section),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: selected ? const Color(0xFF251538) : Colors.transparent,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(section.icon, color: selected ? Colors.white : const Color(0xFF8C8198), size: 18),
                    const SizedBox(width: 7),
                    Text(
                      section.label,
                      style: TextStyle(
                        color: selected ? Colors.white : const Color(0xFF4A2A63),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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

class _CoinsSection extends StatelessWidget {
  const _CoinsSection({
    super.key,
    required this.onPackageTap,
    required this.onSendGiftTap,
    required this.onLuckyPacketTap,
    required this.onGameCoinsTap,
  });

  final ValueChanged<CoinPackage> onPackageTap;
  final VoidCallback onSendGiftTap;
  final VoidCallback onLuckyPacketTap;
  final VoidCallback onGameCoinsTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WalletInfoCard(
          title: 'Coins',
          subtitle: 'Used for gifts, Lucky Packet, entrance effects, themes, store purchases, and coin games.',
          icon: Icons.monetization_on_rounded,
          accent: const Color(0xFFC99A3B),
          rows: const [
            _WalletInfoRow(label: 'Available', value: '35,494'),
            _WalletInfoRow(label: 'Base pack', value: '20,000 coins / ₹120'),
            _WalletInfoRow(label: 'Payment methods', value: 'UPI, GPay'),
          ],
        ),
        const SizedBox(height: 12),
        _CoinPackageList(onPackageTap: onPackageTap),
        const SizedBox(height: 12),
        _WalletActionGrid(
          actions: [
            _WalletAction(title: 'Send Gifts', subtitle: 'Gift spending', icon: Icons.card_giftcard_rounded, onTap: onSendGiftTap),
            _WalletAction(title: 'Lucky Packet', subtitle: 'Packet ledger', icon: Icons.redeem_rounded, onTap: onLuckyPacketTap),
            _WalletAction(title: 'Coin Games', subtitle: 'Game balance', icon: Icons.sports_esports_rounded, onTap: onGameCoinsTap),
            _WalletAction(title: 'Transactions', subtitle: 'Coin ledger', icon: Icons.receipt_long_rounded, onTap: onGameCoinsTap),
          ],
        ),
      ],
    );
  }
}

class _CoinPackageList extends StatelessWidget {
  const _CoinPackageList({required this.onPackageTap});

  final ValueChanged<CoinPackage> onPackageTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFECE2D8)),
        boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.add_card_rounded, color: Color(0xFFC99A3B), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Coin Recharge Packs', style: TextStyle(color: Color(0xFF251538), fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Tap a pack to choose UPI or GPay.', style: TextStyle(color: Color(0xFF6F627A), fontSize: 11.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _coinPackages.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.42,
            ),
            itemBuilder: (context, index) => _CoinPackageCard(
              package: _coinPackages[index],
              onTap: () => onPackageTap(_coinPackages[index]),
            ),
          ),
        ],
      ),
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
      color: const Color(0xFFFAF7F1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFECE2D8)),
          ),
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
                      gradient: const LinearGradient(colors: [Color(0xFFFFD166), Color(0xFFC99A3B)]),
                      boxShadow: [BoxShadow(color: const Color(0xFFC99A3B).withValues(alpha: 0.20), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 17),
                  ),
                  const Spacer(),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE84C72).withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(badge, style: const TextStyle(color: Color(0xFFE84C72), fontSize: 8.5, fontWeight: FontWeight.w900)),
                    ),
                ],
              ),
              const Spacer(),
              Text('${package.coinsText} coins', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(package.priceText, style: const TextStyle(color: Color(0xFFC99A3B), fontSize: 13, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RubySection extends StatelessWidget {
  const _RubySection({
    super.key,
    required this.onConvertTap,
    required this.onEarningsTap,
    required this.onPayoutTap,
    required this.onRulesTap,
  });

  final VoidCallback onConvertTap;
  final VoidCallback onEarningsTap;
  final VoidCallback onPayoutTap;
  final VoidCallback onRulesTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WalletInfoCard(
          title: 'Ruby',
          subtitle: 'Ruby balance is 30% of coins received from gifts. Example: 100 gift coins received = 30 Ruby.',
          icon: Icons.diamond_rounded,
          accent: const Color(0xFFE84C72),
          rows: const [
            _WalletInfoRow(label: 'Available Ruby', value: '8,260'),
            _WalletInfoRow(label: 'Gift receive rule', value: '30% Ruby'),
            _WalletInfoRow(label: 'Convert rule', value: '30 Ruby = 30 Coins'),
          ],
        ),
        const SizedBox(height: 12),
        _RubyRuleCard(onConvertTap: onConvertTap),
        const SizedBox(height: 12),
        _WalletActionGrid(
          actions: [
            _WalletAction(title: 'Ruby Earnings', subtitle: 'Reward details', icon: Icons.savings_rounded, onTap: onEarningsTap),
            _WalletAction(title: 'Convert Ruby', subtitle: '30 Ruby = 30 Coins', icon: Icons.swap_horiz_rounded, onTap: onConvertTap),
            _WalletAction(title: 'Payout', subtitle: 'Request review', icon: Icons.payments_rounded, onTap: onPayoutTap),
            _WalletAction(title: 'Ruby Rules', subtitle: 'Eligibility', icon: Icons.rule_rounded, onTap: onRulesTap),
          ],
        ),
      ],
    );
  }
}

class _RubyRuleCard extends StatelessWidget {
  const _RubyRuleCard({required this.onConvertTap});

  final VoidCallback onConvertTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFECE2D8)),
        boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.diamond_rounded, color: Color(0xFFE84C72), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Ruby Conversion', style: TextStyle(color: Color(0xFF251538), fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _RubyFormulaRow(left: '100 gift coins received', right: '30 Ruby'),
          const SizedBox(height: 8),
          const _RubyFormulaRow(left: '30 Ruby converted', right: '30 Coins'),
          const SizedBox(height: 12),
          _WalletPrimaryButton(label: 'Convert 30 Ruby', icon: Icons.swap_horiz_rounded, onTap: onConvertTap),
        ],
      ),
    );
  }
}

class _RubyFormulaRow extends StatelessWidget {
  const _RubyFormulaRow({required this.left, required this.right});

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(left, style: const TextStyle(color: Color(0xFF6F627A), fontSize: 12, fontWeight: FontWeight.w800))),
        const Icon(Icons.arrow_forward_rounded, color: Color(0xFF8C8198), size: 16),
        const SizedBox(width: 8),
        Text(right, style: const TextStyle(color: Color(0xFFE84C72), fontSize: 12.5, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _PaymentMethodSheet extends StatelessWidget {
  const _PaymentMethodSheet({required this.package, required this.onMethodSelected});

  final CoinPackage package;
  final ValueChanged<String> onMethodSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 16),
      decoration: const BoxDecoration(
        color: Color(0xFF12101D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Select Payment Method', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${package.coinsText} coins • ${package.priceText}', style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _PaymentMethodTile(
            icon: Icons.account_balance_rounded,
            title: 'UPI',
            subtitle: 'Pay with any UPI app',
            onTap: () => onMethodSelected('UPI'),
          ),
          const SizedBox(height: 10),
          _PaymentMethodTile(
            icon: Icons.payments_rounded,
            title: 'G Pay',
            subtitle: 'Pay with Google Pay',
            onTap: () => onMethodSelected('G Pay'),
          ),
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _RubyConvertSheet extends StatelessWidget {
  const _RubyConvertSheet({required this.onConvert});

  final VoidCallback onConvert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 16),
      decoration: const BoxDecoration(
        color: Color(0xFF12101D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Convert Ruby', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text('30 Ruby can be converted into 30 Coins.', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onConvert,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(colors: [Color(0xFFE84C72), Color(0xFF8C5CF6)]),
              ),
              child: const Text('Convert 30 Ruby → 30 Coins', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletInfoCard extends StatelessWidget {
  const _WalletInfoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.rows,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<_WalletInfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFECE2D8)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Color(0xFF6F627A), fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(row.label, style: const TextStyle(color: Color(0xFF6F627A), fontSize: 12, fontWeight: FontWeight.w800))),
                    Text(row.value, style: const TextStyle(color: Color(0xFF251538), fontSize: 13, fontWeight: FontWeight.w900)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _WalletInfoRow {
  const _WalletInfoRow({required this.label, required this.value});

  final String label;
  final String value;
}

class _WalletActionGrid extends StatelessWidget {
  const _WalletActionGrid({required this.actions});

  final List<_WalletAction> actions;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) => _WalletActionCard(action: actions[index]),
    );
  }
}

class _WalletAction {
  const _WalletAction({required this.title, required this.subtitle, required this.icon, required this.onTap});

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class _WalletActionCard extends StatelessWidget {
  const _WalletActionCard({required this.action});

  final _WalletAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: action.onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFECE2D8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, color: const Color(0xFF4A2A63), size: 22),
              const SizedBox(height: 8),
              Text(action.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 12.5, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(action.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 10.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletPrimaryButton extends StatelessWidget {
  const _WalletPrimaryButton({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF251538), size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Color(0xFF251538), fontSize: 12, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _WalletGhostButton extends StatelessWidget {
  const _WalletGhostButton({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
