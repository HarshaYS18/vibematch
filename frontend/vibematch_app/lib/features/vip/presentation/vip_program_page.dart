import 'package:flutter/material.dart';

import '../data/vip_program_mock_repository.dart';
import '../models/vip_program_models.dart';
import 'widgets/vip_shield_badge.dart';

class VipProgramPage extends StatefulWidget {
  const VipProgramPage({
    super.key,
    this.initialTabIndex = 0,
    this.vipLevel = 25,
    this.svipLevel = 3,
    this.lifetimeRechargeCoins = 128500,
    this.monthlyRechargeCoins = 42000,
  });

  final int initialTabIndex;
  final int vipLevel;
  final int svipLevel;
  final int lifetimeRechargeCoins;
  final int monthlyRechargeCoins;

  @override
  State<VipProgramPage> createState() => _VipProgramPageState();
}

class _VipProgramPageState extends State<VipProgramPage> {
  static const Color pearl = Color(0xFFFAF7F1);
  static const Color plum = Color(0xFF251538);
  static const Color deepViolet = Color(0xFF4A2A63);
  static const Color aqua = Color(0xFF12C7B7);
  static const Color violet = Color(0xFF6D5DF6);
  static const Color coral = Color(0xFFE84C72);
  static const Color champagne = Color(0xFFC99A3B);
  static const Color softBorder = Color(0xFFECE2D8);

  late int _selectedTabIndex;
  late final VipProgramSnapshot _snapshot;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex.clamp(0, 1).toInt();
    _snapshot = const VipProgramMockRepository().loadSnapshot(
      vipLevel: widget.vipLevel,
      svipLevel: widget.svipLevel,
      lifetimeRechargeCoins: widget.lifetimeRechargeCoins,
      monthlyRechargeCoins: widget.monthlyRechargeCoins,
    );
  }

  void _showAction(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: plum,
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pearl,
      body: SafeArea(
        child: Column(
          children: [
            _VipHeader(
              selectedTabIndex: _selectedTabIndex,
              onBack: () => Navigator.of(context).maybePop(),
              onTabChanged: (index) => setState(() => _selectedTabIndex = index),
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedTabIndex,
                children: [
                  _VipTab(
                    snapshot: _snapshot,
                    onRechargeTap: () => _showAction('Recharge page will open.'),
                    onRewardTap: (reward) => _showAction('${reward.title} details will open.'),
                  ),
                  _SvipTab(
                    snapshot: _snapshot,
                    onRechargeTap: () => _showAction('Monthly SVIP recharge page will open.'),
                    onRewardTap: (reward) => _showAction('${reward.title} details will open.'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VipHeader extends StatelessWidget {
  const _VipHeader({
    required this.selectedTabIndex,
    required this.onBack,
    required this.onTabChanged,
  });

  final int selectedTabIndex;
  final VoidCallback onBack;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        border: const Border(bottom: BorderSide(color: _VipProgramPageState.softBorder)),
        boxShadow: [
          BoxShadow(
            color: _VipProgramPageState.plum.withValues(alpha: 0.055),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _RoundIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'VIP Center',
              style: TextStyle(
                color: _VipProgramPageState.plum,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          _SegmentedPill(
            selectedIndex: selectedTabIndex,
            labels: const ['VIP', 'SVIP'],
            onChanged: onTabChanged,
          ),
        ],
      ),
    );
  }
}

class _VipTab extends StatelessWidget {
  const _VipTab({
    required this.snapshot,
    required this.onRechargeTap,
    required this.onRewardTap,
  });

  final VipProgramSnapshot snapshot;
  final VoidCallback onRechargeTap;
  final ValueChanged<VipRewardConfig> onRewardTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _VipHeroPager(
          levels: snapshot.vipLevels,
          currentLevel: snapshot.vipLevel,
          currentCoins: snapshot.lifetimeRechargeCoins,
          onRechargeTap: onRechargeTap,
        ),
        const SizedBox(height: 16),
        const _SectionTitle(
          title: 'Privileges',
          subtitle: 'Backend can update rewards anytime.',
        ),
        const SizedBox(height: 10),
        ...snapshot.vipRewards.map(
          (reward) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _RewardCard(
              reward: reward,
              unlocked: (reward.unlockVipLevel ?? 0) <= snapshot.vipLevel,
              unlockLabel: 'VIP ${reward.unlockVipLevel}',
              onTap: () => onRewardTap(reward),
            ),
          ),
        ),
      ],
    );
  }
}

class _SvipTab extends StatelessWidget {
  const _SvipTab({
    required this.snapshot,
    required this.onRechargeTap,
    required this.onRewardTap,
  });

  final VipProgramSnapshot snapshot;
  final VoidCallback onRechargeTap;
  final ValueChanged<VipRewardConfig> onRewardTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _SvipHeroPager(
          levels: snapshot.svipLevels,
          currentLevel: snapshot.svipLevel,
          currentCoins: snapshot.monthlyRechargeCoins,
          onRechargeTap: onRechargeTap,
        ),
        const SizedBox(height: 14),
        const _CompactPolicyCard(
          text: 'SVIP is monthly. If the required monthly recharge is not maintained, it drops by 2 levels next month and can reach 0.',
        ),
        const SizedBox(height: 16),
        const _SectionTitle(
          title: 'Privileges',
          subtitle: 'Monthly rewards while SVIP is active.',
        ),
        const SizedBox(height: 10),
        ...snapshot.svipRewards.map(
          (reward) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _RewardCard(
              reward: reward,
              unlocked: (reward.unlockSvipLevel ?? 0) <= snapshot.svipLevel,
              unlockLabel: 'SVIP ${reward.unlockSvipLevel}',
              onTap: () => onRewardTap(reward),
            ),
          ),
        ),
      ],
    );
  }
}

class _VipHeroPager extends StatefulWidget {
  const _VipHeroPager({
    required this.levels,
    required this.currentLevel,
    required this.currentCoins,
    required this.onRechargeTap,
  });

  final List<VipLevelConfig> levels;
  final int currentLevel;
  final int currentCoins;
  final VoidCallback onRechargeTap;

  @override
  State<_VipHeroPager> createState() => _VipHeroPagerState();
}

class _VipHeroPagerState extends State<_VipHeroPager> {
  late final PageController _controller;
  late int _pageIndex;

  @override
  void initState() {
    super.initState();
    final maxIndex = widget.levels.isEmpty ? 0 : widget.levels.length - 1;
    final initialPage = (widget.currentLevel - 1).clamp(0, maxIndex).toInt();
    _pageIndex = initialPage;
    _controller = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.levels.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.levels.length,
            onPageChanged: (index) => setState(() => _pageIndex = index),
            itemBuilder: (context, index) {
              final level = widget.levels[index];
              return _VipHeroCard(
                level: level.level,
                requiredCoins: level.requiredRechargeCoins,
                currentCoins: widget.currentCoins,
                onPrimaryAction: widget.onRechargeTap,
              );
            },
          ),
        ),
        const SizedBox(height: 9),
        _HeroPageHint(
          current: _pageIndex + 1,
          total: widget.levels.length,
          label: 'Swipe VIP levels',
        ),
      ],
    );
  }
}

class _SvipHeroPager extends StatefulWidget {
  const _SvipHeroPager({
    required this.levels,
    required this.currentLevel,
    required this.currentCoins,
    required this.onRechargeTap,
  });

  final List<SvipLevelConfig> levels;
  final int currentLevel;
  final int currentCoins;
  final VoidCallback onRechargeTap;

  @override
  State<_SvipHeroPager> createState() => _SvipHeroPagerState();
}

class _SvipHeroPagerState extends State<_SvipHeroPager> {
  late final PageController _controller;
  late int _pageIndex;

  @override
  void initState() {
    super.initState();
    final maxIndex = widget.levels.isEmpty ? 0 : widget.levels.length - 1;
    final initialPage = (widget.currentLevel - 1).clamp(0, maxIndex).toInt();
    _pageIndex = initialPage;
    _controller = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.levels.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.levels.length,
            onPageChanged: (index) => setState(() => _pageIndex = index),
            itemBuilder: (context, index) {
              final level = widget.levels[index];
              return _SvipHeroCard(
                level: level.level,
                requiredCoins: level.monthlyRechargeCoins,
                currentCoins: widget.currentCoins,
                onPrimaryAction: widget.onRechargeTap,
              );
            },
          ),
        ),
        const SizedBox(height: 9),
        _HeroPageHint(
          current: _pageIndex + 1,
          total: widget.levels.length,
          label: 'Swipe SVIP levels',
        ),
      ],
    );
  }
}

class _VipHeroCard extends StatelessWidget {
  const _VipHeroCard({
    required this.level,
    required this.requiredCoins,
    required this.currentCoins,
    required this.onPrimaryAction,
  });

  final int level;
  final int requiredCoins;
  final int currentCoins;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final progress = requiredCoins <= 0
        ? 1.0
        : (currentCoins / requiredCoins).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _heroDecoration(
        const [Color(0xFF1C0F2A), Color(0xFF4A2A63), Color(0xFF111827)],
        _VipProgramPageState.deepViolet,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -34,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white.withValues(alpha: 0.08),
              size: 126,
            ),
          ),
          Positioned(right: 0, top: 0, child: VipShieldBadge(level: level, size: 62)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text('VIP $level', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
              const SizedBox(height: 24),
              _ProgressBlock(
                progress: progress,
                label: '${_formatCoins(currentCoins)} / ${_formatCoins(requiredCoins)} coins',
                color: _VipProgramPageState.champagne,
              ),
              const SizedBox(height: 14),
              _CoinStatRow(
                currentLabel: '${_formatCoins(currentCoins)} recharged',
                requiredLabel: '${_formatCoins(requiredCoins)} total',
              ),
              const Spacer(),
              _PremiumButton(label: 'Recharge', onTap: onPrimaryAction),
            ],
          ),
        ],
      ),
    );
  }
}

class _SvipHeroCard extends StatelessWidget {
  const _SvipHeroCard({
    required this.level,
    required this.requiredCoins,
    required this.currentCoins,
    required this.onPrimaryAction,
  });

  final int level;
  final int requiredCoins;
  final int currentCoins;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final progress = requiredCoins <= 0
        ? 1.0
        : (currentCoins / requiredCoins).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _heroDecoration(
        const [Color(0xFF251538), Color(0xFF6D5DF6), Color(0xFFE84C72)],
        _VipProgramPageState.violet,
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
                boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.16), blurRadius: 22)],
              ),
              child: const Icon(Icons.diamond_rounded, color: Color(0xFFFFD36A), size: 31),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text('SVIP $level', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
              const SizedBox(height: 24),
              _ProgressBlock(
                progress: progress,
                label: '${_formatCoins(currentCoins)} / ${_formatCoins(requiredCoins)} monthly coins',
                color: const Color(0xFFFFD36A),
              ),
              const SizedBox(height: 14),
              _CoinStatRow(
                currentLabel: '${_formatCoins(currentCoins)} this month',
                requiredLabel: '${_formatCoins(requiredCoins)} total',
              ),
              const Spacer(),
              _PremiumButton(label: 'Recharge', onTap: onPrimaryAction),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoinStatRow extends StatelessWidget {
  const _CoinStatRow({required this.currentLabel, required this.requiredLabel});

  final String currentLabel;
  final String requiredLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _CoinStatPill(label: currentLabel, icon: Icons.account_balance_wallet_rounded)),
        const SizedBox(width: 8),
        Expanded(child: _CoinStatPill(label: requiredLabel, icon: Icons.flag_rounded)),
      ],
    );
  }
}

class _CoinStatPill extends StatelessWidget {
  const _CoinStatPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.82), size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 11.5, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPageHint extends StatelessWidget {
  const _HeroPageHint({required this.current, required this.total, required this.label});

  final int current;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.swipe_rounded, size: 16, color: Color(0xFF8C8198)),
        const SizedBox(width: 6),
        Text(
          '$label · $current/$total',
          style: const TextStyle(color: Color(0xFF8C8198), fontSize: 11.5, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.reward,
    required this.unlocked,
    required this.unlockLabel,
    required this.onTap,
  });

  final VipRewardConfig reward;
  final bool unlocked;
  final String unlockLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.98),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: unlocked ? _VipProgramPageState.champagne.withValues(alpha: 0.42) : _VipProgramPageState.softBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: unlocked
                      ? const LinearGradient(colors: [_VipProgramPageState.champagne, _VipProgramPageState.coral])
                      : const LinearGradient(colors: [Color(0xFFE8E0D8), Color(0xFFB7ACBF)]),
                ),
                child: Icon(reward.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  reward.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _VipProgramPageState.plum, fontSize: 13.5, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              _MiniStatusPill(label: unlocked ? 'Unlocked' : unlockLabel, active: unlocked),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactPolicyCard extends StatelessWidget {
  const _CompactPolicyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _VipProgramPageState.softBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: _VipProgramPageState.violet, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF7A6B86), fontSize: 12.5, height: 1.25, fontWeight: FontWeight.w700),
            ),
          ),
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: _VipProgramPageState.plum, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(color: Color(0xFF7A6B86), fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.progress, required this.label, required this.color});

  final double progress;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            backgroundColor: Colors.white.withValues(alpha: 0.16),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.86), fontSize: 12.5, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _PremiumButton extends StatelessWidget {
  const _PremiumButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(colors: [Color(0xFFFFD36A), Color(0xFFC99A3B)]),
          boxShadow: [BoxShadow(color: const Color(0xFFFFD36A).withValues(alpha: 0.24), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Text(label, style: const TextStyle(color: _VipProgramPageState.plum, fontSize: 13, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _MiniStatusPill extends StatelessWidget {
  const _MiniStatusPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: active ? _VipProgramPageState.aqua.withValues(alpha: 0.12) : const Color(0xFFF4EEE8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? _VipProgramPageState.aqua.withValues(alpha: 0.32) : _VipProgramPageState.softBorder),
      ),
      child: Text(label, style: TextStyle(color: active ? _VipProgramPageState.plum : const Color(0xFF8C8198), fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }
}

class _SegmentedPill extends StatelessWidget {
  const _SegmentedPill({required this.selectedIndex, required this.labels, required this.onChanged});

  final int selectedIndex;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EEE8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _VipProgramPageState.softBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < labels.length; index++)
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: selectedIndex == index ? _VipProgramPageState.plum : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  labels[index],
                  style: TextStyle(
                    color: selectedIndex == index ? Colors.white : _VipProgramPageState.deepViolet,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFF4EEE8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _VipProgramPageState.softBorder),
        ),
        child: Icon(icon, color: _VipProgramPageState.plum, size: 18),
      ),
    );
  }
}

BoxDecoration _heroDecoration(List<Color> colors, Color shadowColor) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(30),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    ),
    boxShadow: [
      BoxShadow(
        color: shadowColor.withValues(alpha: 0.26),
        blurRadius: 28,
        offset: const Offset(0, 16),
      ),
    ],
  );
}

String _formatCoins(int value) {
  if (value >= 1000000) {
    final result = value / 1000000;
    return '${result.toStringAsFixed(result >= 10 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    final result = value / 1000;
    return '${result.toStringAsFixed(result >= 10 ? 0 : 1)}K';
  }
  return value.toString();
}
