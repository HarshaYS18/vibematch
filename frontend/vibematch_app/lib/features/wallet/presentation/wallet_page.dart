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
                  onRechargeTap: () => _showMockToast('Recharge flow opened'),
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
                          onRechargeTap: () => _showMockToast('Coin recharge packages opened'),
                          onSendGiftTap: () => _showMockToast('Gift section opened'),
                          onLuckyPacketTap: () => _showMockToast('Lucky Packet wallet ledger opened'),
                          onGameCoinsTap: () => _showMockToast('Coin games wallet controls opened'),
                        )
                      : _RubySection(
                          key: const ValueKey('ruby'),
                          onConvertTap: () => _showMockToast('Ruby conversion flow opened'),
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
    final subtitle = isCoins ? 'For gifts, Lucky Packet, store and games' : 'Creator rewards and payout value';
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
                  label: isCoins ? 'Recharge' : 'Convert / Payout',
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
    required this.onRechargeTap,
    required this.onSendGiftTap,
    required this.onLuckyPacketTap,
    required this.onGameCoinsTap,
  });

  final VoidCallback onRechargeTap;
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
            _WalletInfoRow(label: 'Today spent', value: '1,280'),
            _WalletInfoRow(label: 'Pending refund', value: '0'),
          ],
        ),
        const SizedBox(height: 12),
        _WalletActionGrid(
          actions: [
            _WalletAction(title: 'Recharge Coins', subtitle: 'Buy coin packs', icon: Icons.add_card_rounded, onTap: onRechargeTap),
            _WalletAction(title: 'Send Gifts', subtitle: 'Gift spending', icon: Icons.card_giftcard_rounded, onTap: onSendGiftTap),
            _WalletAction(title: 'Lucky Packet', subtitle: 'Packet ledger', icon: Icons.redeem_rounded, onTap: onLuckyPacketTap),
            _WalletAction(title: 'Coin Games', subtitle: 'Game balance', icon: Icons.sports_esports_rounded, onTap: onGameCoinsTap),
          ],
        ),
      ],
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
          subtitle: 'Ruby is the creator-side reward balance from eligible gifts, host activity, and campaigns.',
          icon: Icons.diamond_rounded,
          accent: const Color(0xFFE84C72),
          rows: const [
            _WalletInfoRow(label: 'Available Ruby', value: '8,260'),
            _WalletInfoRow(label: 'Under review', value: '420'),
            _WalletInfoRow(label: 'This month', value: '12.4K'),
          ],
        ),
        const SizedBox(height: 12),
        _WalletActionGrid(
          actions: [
            _WalletAction(title: 'Ruby Earnings', subtitle: 'Reward details', icon: Icons.savings_rounded, onTap: onEarningsTap),
            _WalletAction(title: 'Convert Ruby', subtitle: 'Mock conversion', icon: Icons.swap_horiz_rounded, onTap: onConvertTap),
            _WalletAction(title: 'Payout', subtitle: 'Request review', icon: Icons.payments_rounded, onTap: onPayoutTap),
            _WalletAction(title: 'Ruby Rules', subtitle: 'Eligibility', icon: Icons.rule_rounded, onTap: onRulesTap),
          ],
        ),
      ],
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
