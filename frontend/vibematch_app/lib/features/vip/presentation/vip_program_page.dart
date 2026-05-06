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
    _selectedTabIndex = widget.initialTabIndex.clamp(0, 1);
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
    final needed = (next.requiredRechargeCoins - snapshot.lifetimeRechargeCoins).clamp(0, 999999999);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _VipHeroCard(
          level: snapshot.vipLevel,
          title: 'VIP ${snapshot.vipLevel}',
          subtitle: 'Lifetime recharge status',
          progress: snapshot.vipProgress,
          progressLabel: needed == 0
              ? 'Highest visible VIP milestone reached'
              : '${_formatCoins(needed)} coins to VIP ${next.level}',
          primaryAction: 'Recharge',
          onPrimaryAction: onRechargeTap,
        ),
        const SizedBox(height: 14),
        _InfoPanel(
          title: 'VIP progression flow',
          rows: const [
            _InfoRowData('VIP 1–10', 'Easy progression for new rechargers.'),
            _InfoRowData('VIP 11–20', 'Medium progression with stronger room identity rewards.'),
            _InfoRowData('VIP 21–30', 'Hard progression for committed spenders.'),
            _InfoRowData('VIP 31–40', 'Very hard progression with priority protection rewards.'),
            _InfoRowData('VIP 41–50', 'Insane progression for top lifetime supporters.'),
          ],
        ),
        const SizedBox(height: 14),
        _SectionTitle(title: 'Level privileges', subtitle: 'Config-driven rewards can be changed later from backend.'),
        const SizedBox(height: 10),
        ...snapshot.vipRewards.map(
          (reward) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RewardCard(
              reward: reward,
              unlocked: (reward.unlockVipLevel ?? 0) <= snapshot.vipLevel,
              unlockLabel: 'VIP ${reward.unlockVipLevel}',
              onTap: () => onRewardTap(reward),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _VipLevelTrack(levels: snapshot.vipLevels, currentLevel: snapshot.vipLevel),
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
    final needed = (next.monthlyRechargeCoins - snapshot.monthlyRechargeCoins).clamp(0, 999999999);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _SvipHeroCard(
          level: snapshot.svipLevel,
          progress: snapshot.svipProgress,
          progressLabel: needed == 0
              ? 'SVIP ${snapshot.svipLevel} monthly target completed'
              : '${_formatCoins(needed)} coins to SVIP ${next.level}',
          onPrimaryAction: onRechargeTap,
        ),
        const SizedBox(height: 14),
        _InfoPanel(
          title: 'Monthly SVIP maintenance',
          rows: const [
            _InfoRowData('Monthly status', 'SVIP is recalculated every month from monthly recharge activity.'),
            _InfoRowData('Harder every level', 'Each SVIP level needs more monthly recharge coins than the previous level.'),
            _InfoRowData('Grace drop rule', 'If the monthly target is not maintained, SVIP drops by 2 levels next month.'),
            _InfoRowData('Can reach zero', 'Repeated missed maintenance continues dropping until SVIP returns to 0.'),
          ],
        ),
        const SizedBox(height: 14),
        _SectionTitle(title: 'SVIP privileges', subtitle: 'Highest monthly tier is SVIP 10.'),
        const SizedBox(height: 10),
        ...snapshot.svipRewards.map(
          (reward) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RewardCard(
              reward: reward,
              unlocked: (reward.unlockSvipLevel ?? 0) <= snapshot.svipLevel,
              unlockLabel: 'SVIP ${reward.unlockSvipLevel}',
              onTap: () => onRewardTap(reward),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _SvipLevelTrack(levels: snapshot.svipLevels, currentLevel: snapshot.svipLevel),
      ],
    );
  }
}

class _VipHeroCard extends StatelessWidget {
  const _VipHeroCard({
    required this.level,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.progressLabel,
    required this.primaryAction,
    required this.onPrimaryAction,
  });

  final int level;
  final String title;
  final String subtitle;
  final double progress;
  final String progressLabel;
  final String primaryAction;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C0F2A), Color(0xFF4A2A63), Color(0xFF111827)],
        ),
        boxShadow: [
          BoxShadow(
            color: _VipProgramPageState.deepViolet.withValues(alpha: 0.26),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
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
              const _HeroTag(label: 'Lifetime VIP'),
              const SizedBox(height: 20),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.74), fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 22),
              _ProgressBlock(progress: progress, label: progressLabel, color: _VipProgramPageState.champagne),
              const SizedBox(height: 18),
              _PremiumButton(label: primaryAction, onTap: onPrimaryAction),
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF251538), Color(0xFF6D5DF6), Color(0xFFE84C72)],
        ),
        boxShadow: [
          BoxShadow(
            color: _VipProgramPageState.violet.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _HeroTag(label: 'Monthly SVIP'),
              const Spacer(),
              Container(
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
            ],
          ),
          const SizedBox(height: 18),
          Text('SVIP $level', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
          const SizedBox(height: 4),
          Text('Monthly premium status · max SVIP 10', style: TextStyle(color: Colors.white.withValues(alpha: 0.74), fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 22),
          _ProgressBlock(progress: progress, label: progressLabel, color: const Color(0xFFFFD36A)),
          const SizedBox(height: 18),
          _PremiumButton(label: 'Recharge monthly', onTap: onPrimaryAction),
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
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: unlocked ? _VipProgramPageState.champagne.withValues(alpha: 0.48) : _VipProgramPageState.softBorder),
            boxShadow: [
              BoxShadow(
                color: _VipProgramPageState.plum.withValues(alpha: 0.055),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: unlocked
                      ? const LinearGradient(colors: [_VipProgramPageState.champagne, _VipProgramPageState.coral])
                      : const LinearGradient(colors: [Color(0xFFE8E0D8), Color(0xFFB7ACBF)]),
                ),
                child: Icon(reward.icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            reward.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _VipProgramPageState.plum, fontSize: 14.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                        _MiniStatusPill(label: unlocked ? 'Unlocked' : unlockLabel, active: unlocked),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      reward.description,
                      style: const TextStyle(color: Color(0xFF7A6B86), fontSize: 12.5, fontWeight: FontWeight.w650, height: 1.25),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VipLevelTrack extends StatelessWidget {
  const _VipLevelTrack({required this.levels, required this.currentLevel});

  final List<VipLevelConfig> levels;
  final int currentLevel;

  @override
  Widget build(BuildContext context) {
    final milestones = levels.where((level) => level.level == 1 || level.level % 5 == 0).toList();
    return _TrackPanel(
      title: 'VIP level map',
      children: milestones.map((level) {
        final active = level.level <= currentLevel;
        return _TrackChip(
          label: 'VIP ${level.level}',
          subtitle: level.difficulty.label,
          active: active,
          color: level.difficulty.color,
        );
      }).toList(),
    );
  }
}

class _SvipLevelTrack extends StatelessWidget {
  const _SvipLevelTrack({required this.levels, required this.currentLevel});

  final List<SvipLevelConfig> levels;
  final int currentLevel;

  @override
  Widget build(BuildContext context) {
    return _TrackPanel(
      title: 'SVIP monthly map',
      children: levels.map((level) {
        final active = level.level <= currentLevel;
        return _TrackChip(
          label: 'SVIP ${level.level}',
          subtitle: _formatCoins(level.monthlyRechargeCoins),
          active: active,
          color: _VipProgramPageState.violet,
        );
      }).toList(),
    );
  }
}

class _TrackPanel extends StatelessWidget {
  const _TrackPanel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _VipProgramPageState.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _VipProgramPageState.plum, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

class _TrackChip extends StatelessWidget {
  const _TrackChip({required this.label, required this.subtitle, required this.active, required this.color});

  final String label;
  final String subtitle;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.13) : const Color(0xFFF4EEE8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? color.withValues(alpha: 0.42) : _VipProgramPageState.softBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: active ? _VipProgramPageState.plum : const Color(0xFF8C8198), fontSize: 12, fontWeight: FontWeight.w900)),
          Text(subtitle, style: TextStyle(color: active ? color : const Color(0xFF8C8198), fontSize: 10.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.rows});

  final String title;
  final List<_InfoRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _VipProgramPageState.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _VipProgramPageState.plum, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 11),
          ...rows.map((row) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _InfoRow(row: row))),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.row});

  final _InfoRowData row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 5),
          decoration: const BoxDecoration(color: _VipProgramPageState.aqua, shape: BoxShape.circle),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Color(0xFF7A6B86), fontSize: 12.5, height: 1.25, fontWeight: FontWeight.w650),
              children: [
                TextSpan(text: '${row.title}: ', style: const TextStyle(color: _VipProgramPageState.plum, fontWeight: FontWeight.w900)),
                TextSpan(text: row.description),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRowData {
  const _InfoRowData(this.title, this.description);

  final String title;
  final String description;
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
        Text(title, style: const TextStyle(color: _VipProgramPageState.plum, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: Color(0xFF7A6B86), fontSize: 12.5, fontWeight: FontWeight.w700)),
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
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 12.5, fontWeight: FontWeight.w800)),
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

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.86), fontSize: 11, fontWeight: FontWeight.w900)),
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
