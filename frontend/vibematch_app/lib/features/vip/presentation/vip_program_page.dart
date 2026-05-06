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
  late int _selectedTabIndex;
  late VipProgramSnapshot _snapshot;

  static const Color pearl = Color(0xFFFAF7F1);
  static const Color plum = Color(0xFF251538);
  static const Color deepViolet = Color(0xFF4A2A63);
  static const Color aqua = Color(0xFF12C7B7);
  static const Color violet = Color(0xFF6D5DF6);
  static const Color coral = Color(0xFFE84C72);
  static const Color champagne = Color(0xFFC99A3B);
  static const Color softBorder = Color(0xFFECE2D8);

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
    final next = snapshot.nextVipLevel;
    final nextRequired = next.requiredRechargeCoins;
    final progressLabel = next.level <= snapshot.vipLevel
        ? '${_formatCoins(snapshot.lifetimeRechargeCoins)} coins recharged'
        : '${_formatCoins(snapshot.lifetimeRechargeCoins)} / ${_formatCoins(nextRequired)} coins';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _VipHeroCard(
          level: snapshot.vipLevel,
          title: 'VIP ${snapshot.vipLevel}',
          progress: snapshot.vipProgress,
          progressLabel: progressLabel,
          onPrimaryAction: onRechargeTap,
        ),
        const SizedBox(height: 14),
        _SectionTitle(title: 'Swipe VIP levels', subtitle: 'See coins required for every VIP level.'),
        const SizedBox(height: 10),
        _VipLevelPager(
          levels: snapshot.vipLevels,
          currentLevel: snapshot.vipLevel,
          currentCoins: snapshot.lifetimeRechargeCoins,
        ),
        const SizedBox(height: 16),
        _SectionTitle(title: 'Privileges', subtitle: 'Backend can update rewards anytime.'),
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
    final next = snapshot.nextSvipLevel;
    final nextRequired = next.monthlyRechargeCoins;
    final progressLabel = next.level <= snapshot.svipLevel
        ? '${_formatCoins(snapshot.monthlyRechargeCoins)} coins this month'
        : '${_formatCoins(snapshot.monthlyRechargeCoins)} / ${_formatCoins(nextRequired)} monthly coins';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _SvipHeroCard(
          level: snapshot.svipLevel,
          progress: snapshot.svipProgress,
          progressLabel: progressLabel,
          onPrimaryAction: onRechargeTap,
        ),
        const SizedBox(height: 14),
        _CompactPolicyCard(
          text: 'SVIP is monthly. If the required monthly recharge is not maintained, it drops by 2 levels next month and can reach 0.',
        ),
        const SizedBox(height: 14),
        _SectionTitle(title: 'Swipe SVIP levels', subtitle: 'See monthly coins required for SVIP 1–10.'),
        const SizedBox(height: 10),
        _SvipLevelPager(
          levels: snapshot.svipLevels,
          currentLevel: snapshot.svipLevel,
          currentCoins: snapshot.monthlyRechargeCoins,
        ),
        const SizedBox(height: 16),
        _SectionTitle(title: 'Privileges', subtitle: 'Monthly rewards while SVIP is active.'),
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

class _VipHeroCard extends StatelessWidget {
  const _VipHeroCard({
    required this.level,
    required this.title,
    required this.progress,
    required this.progressLabel,
    required this.onPrimaryAction,
  });

  final int level;
  final String title;
  final double progress;
  final String progressLabel;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
              const SizedBox(height: 34),
              _ProgressBlock(progress: progress, label: progressLabel, color: _VipProgramPageState.champagne),
              const SizedBox(height: 18),
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
    required this.progress,
    required this.progressLabel,
    required this.onPrimaryAction,
  });

  final int level;
  final double progress;
  final String progressLabel;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 10),
              Text('SVIP $level', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
              const SizedBox(height: 34),
              _ProgressBlock(progress: progress, label: progressLabel, color: const Color(0xFFFFD36A)),
              const SizedBox(height: 18),
              _PremiumButton(label: 'Recharge', onTap: onPrimaryAction),
            ],
          ),
        ],
      ),
    );
  }
}

class _VipLevelPager extends StatefulWidget {
  const _VipLevelPager({
    required this.levels,
    required this.currentLevel,
    required this.currentCoins,
  });

  final List<VipLevelConfig> levels;
  final int currentLevel;
  final int currentCoins;

  @override
  State<_VipLevelPager> createState() => _VipLevelPagerState();
}

class _VipLevelPagerState extends State<_VipLevelPager> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    final initialPage = (widget.currentLevel - 1).clamp(0, widget.levels.length - 1).toInt();
    _controller = PageController(initialPage: initialPage, viewportFraction: 0.82);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 126,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.levels.length,
        itemBuilder: (context, index) {
          final level = widget.levels[index];
          final active = level.level <= widget.currentLevel;
          final remaining = (level.requiredRechargeCoins - widget.currentCoins).clamp(0, 999999999).toInt();
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _LevelRequirementCard(
              title: 'VIP ${level.level}',
              requiredLabel: '${_formatCoins(level.requiredRechargeCoins)} coins required',
              detailLabel: active ? 'Unlocked' : '${_formatCoins(remaining)} coins remaining',
              active: active,
              accent: level.difficulty.color,
            ),
          );
        },
      ),
    );
  }
}

class _SvipLevelPager extends StatefulWidget {
  const _SvipLevelPager({
    required this.levels,
    required this.currentLevel,
    required this.currentCoins,
  });

  final List<SvipLevelConfig> levels;
  final int currentLevel;
  final int currentCoins;

  @override
  State<_SvipLevelPager> createState() => _SvipLevelPagerState();
}

class _SvipLevelPagerState extends State<_SvipLevelPager> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    final initialPage = (widget.currentLevel - 1).clamp(0, widget.levels.length - 1).toInt();
    _controller = PageController(initialPage: initialPage, viewportFraction: 0.82);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 126,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.levels.length,
        itemBuilder: (context, index) {
          final level = widget.levels[index];
          final active = level.level <= widget.currentLevel;
          final remaining = (level.monthlyRechargeCoins - widget.currentCoins).clamp(0, 999999999).toInt();
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _LevelRequirementCard(
              title: 'SVIP ${level.level}',
              requiredLabel: '${_formatCoins(level.monthlyRechargeCoins)} monthly coins',
              detailLabel: active ? 'Active' : '${_formatCoins(remaining)} coins remaining',
              active: active,
              accent: _VipProgramPageState.violet,
            ),
          );
        },
      ),
    );
  }
}

class _LevelRequirementCard extends StatelessWidget {
  const _LevelRequirementCard({
    required this.title,
    required this.requiredLabel,
    required this.detailLabel,
    required this.active,
    required this.accent,
  });

  final String title;
  final String requiredLabel;
  final String detailLabel;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: active ? accent.withValues(alpha: 0.42) : _VipProgramPageState.softBorder),
        boxShadow: [
          BoxShadow(
            color: _VipProgramPageState.plum.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              color: accent.withValues(alpha: active ? 0.18 : 0.09),
            ),
            child: Icon(active ? Icons.check_rounded : Icons.lock_rounded, color: active ? accent : const Color(0xFF8C8198)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: _VipProgramPageState.plum, fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(requiredLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7A6B86), fontSize: 12.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(detailLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? accent : _VipProgramPageState.coral, fontSize: 12.5, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
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
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.86), fontSize: 12.5, fontWeight: FontWeight.w900)),
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
