part of 'wallet_page_modular.dart';

class _WalletOverview extends StatelessWidget {
  const _WalletOverview({required this.wallet, required this.selectedSection});

  final VmWallet wallet;
  final WalletSection selectedSection;

  @override
  Widget build(BuildContext context) {
    final isCoins = selectedSection == WalletSection.coins;
    final value = isCoins ? wallet.coinBalance : wallet.rubyBalance;
    final title = isCoins ? 'Coin Balance' : 'Ruby Balance';
    final icon = isCoins
        ? Icons.monetization_on_rounded
        : Icons.diamond_rounded;
    final colors = isCoins
        ? const [Color(0xFFFFD166), Color(0xFFE84C72), Color(0xFF6D5DF6)]
        : const [Color(0xFFE84C72), Color(0xFF8C5CF6), Color(0xFF12C7B7)];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatWalletNumber(value),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            wallet.coinPriceText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LevelPill(
                  label: 'VIP',
                  level: wallet.vipLevel,
                  maxLevel: wallet.vipMaxLevel,
                  progress: wallet.vipProgressPercent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LevelPill(
                  label: 'SVIP',
                  level: wallet.svipLevel,
                  maxLevel: wallet.svipMaxLevel,
                  progress: wallet.svipProgressPercent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _GiftLevelPill(
                  icon: Icons.send_rounded,
                  label: 'Sent Lv ${wallet.sentLevel}',
                  value:
                      '${formatWalletNumber(wallet.monthlyGiftCoinsSent)} this month',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GiftLevelPill(
                  icon: Icons.volunteer_activism_rounded,
                  label: 'Receive Lv ${wallet.receiveLevel}',
                  value:
                      '${formatWalletNumber(wallet.monthlyGiftCoinsReceived)} this month',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  const _LevelPill({
    required this.label,
    required this.level,
    required this.maxLevel,
    required this.progress,
  });
  final String label;
  final int level;
  final int maxLevel;
  final double progress;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label $level/$maxLevel',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: (progress / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${progress.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftLevelPill extends StatelessWidget {
  const _GiftLevelPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
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

class _WalletSectionTabs extends StatelessWidget {
  const _WalletSectionTabs({
    required this.selectedSection,
    required this.onChanged,
  });
  final WalletSection selectedSection;
  final ValueChanged<WalletSection> onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: WalletColors.border),
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
                  color: selected ? WalletColors.deep : Colors.transparent,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      section.icon,
                      color: selected ? Colors.white : const Color(0xFF8C8198),
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      section.label,
                      style: TextStyle(
                        color: selected ? Colors.white : WalletColors.plum,
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
    required this.wallet,
    required this.rechargeAmountsInr,
    required this.working,
    required this.onRecharge,
  });
  final VmWallet wallet;
  final List<int> rechargeAmountsInr;
  final bool working;
  final ValueChanged<int> onRecharge;
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
              Expanded(
                child: Text(
                  'Recharge Coins',
                  style: TextStyle(
                    color: WalletColors.deep,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '₹100 = 1,00,000 coins. Recharge updates coin balance, lifetime VIP and monthly SVIP.',
            style: TextStyle(
              color: Color(0xFF6F627A),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _InfoLine(
            label: 'Lifetime recharge',
            value: '${formatWalletNumber(wallet.lifetimeRechargeCoins)} coins',
          ),
          _InfoLine(
            label: 'Monthly recharge',
            value: '${formatWalletNumber(wallet.monthlyRechargeCoins)} coins',
          ),
          const _InfoLine(label: 'Highest VIP target', value: '₹4,00,00,000'),
          const _InfoLine(
            label: 'Highest SVIP monthly target',
            value: '₹20,00,000',
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rechargeAmountsInr.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.55,
            ),
            itemBuilder: (context, index) {
              final amount = rechargeAmountsInr[index];
              return Material(
                color: WalletColors.bg,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: working ? null : () => onRecharge(amount),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: WalletColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.monetization_on_rounded,
                          color: WalletColors.gold,
                          size: 24,
                        ),
                        const Spacer(),
                        Text(
                          '${formatWalletNumber(amount * 1000)} coins',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: WalletColors.deep,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '₹$amount',
                          style: const TextStyle(
                            color: WalletColors.gold,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RubySection extends StatelessWidget {
  const _RubySection({
    required this.wallet,
    required this.controller,
    required this.working,
    required this.onConvert,
  });
  final VmWallet wallet;
  final TextEditingController controller;
  final bool working;
  final VoidCallback onConvert;
  @override
  Widget build(BuildContext context) {
    return WalletWhiteCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.diamond_rounded, color: WalletColors.coral, size: 21),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ruby Actions',
                  style: TextStyle(
                    color: WalletColors.deep,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoLine(
            label: 'Ruby balance',
            value: formatWalletNumber(wallet.rubyBalance),
          ),
          _InfoLine(
            label: 'Withdrawable Ruby',
            value: formatWalletNumber(wallet.withdrawableRubies),
          ),
          _InfoLine(
            label: 'Coin balance',
            value: formatWalletNumber(wallet.coinBalance),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter Ruby amount to convert',
              filled: true,
              fillColor: WalletColors.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: WalletColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: WalletColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: WalletColors.coral),
              ),
            ),
          ),
          const SizedBox(height: 10),
          WalletPrimarySmallButton(
            text: working ? 'Please wait...' : 'Convert 1 Ruby = 1 Coin',
            onTap: working ? () {} : onConvert,
          ),
        ],
      ),
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({required this.entries});
  final List<VmWalletLedgerEntry> entries;
  @override
  Widget build(BuildContext context) {
    return WalletWhiteCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Real Ledger',
            style: TextStyle(
              color: WalletColors.deep,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Text(
              'No wallet ledger entries yet.',
              style: TextStyle(
                color: Color(0xFF6F627A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            ...entries.take(12).map((entry) => _LedgerRow(entry: entry)),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});
  final VmWalletLedgerEntry entry;
  @override
  Widget build(BuildContext context) {
    final credit = entry.direction == 'credit';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: WalletColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WalletColors.border),
      ),
      child: Row(
        children: [
          Icon(
            credit ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
            color: credit ? WalletColors.aqua : WalletColors.coral,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.reason ?? entry.source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WalletColors.deep,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.source} • ${entry.currency}',
                  style: const TextStyle(
                    color: Color(0xFF6F627A),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${credit ? '+' : '-'}${formatWalletNumber(entry.amount)}',
            style: TextStyle(
              color: credit ? WalletColors.aqua : WalletColors.coral,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6F627A),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: WalletColors.deep,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
