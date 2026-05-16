import 'package:flutter/material.dart';

import '../controllers/vip_center_controller.dart';
import '../models/vip_models.dart';

class VipPage extends StatefulWidget {
  const VipPage({super.key});

  @override
  State<VipPage> createState() => _VipPageState();
}

class _VipPageState extends State<VipPage> {
  late final VipCenterController _controller;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _controller = VipCenterController()..addListener(_onChanged);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  VipProgress get _selectedProgress => _selectedTab == 0 ? _controller.payload.vip : _controller.payload.svip;

  @override
  Widget build(BuildContext context) {
    final progress = _selectedProgress;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F1),
        elevation: 0,
        foregroundColor: const Color(0xFF251538),
        title: const Text('VIP & SVIP', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: _controller.load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _controller.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF12C7B7)))
          : _controller.errorMessage != null
              ? _VipErrorState(message: _controller.errorMessage!, onRetry: _controller.load)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    _VipSwitchTabs(
                      selectedIndex: _selectedTab,
                      onChanged: (index) => setState(() => _selectedTab = index),
                    ),
                    const SizedBox(height: 14),
                    _VipHeroCard(progress: progress),
                    const SizedBox(height: 14),
                    _VipMetricCard(
                      progress: progress,
                      totalRechargeLabel: _selectedTab == 0 ? 'Lifetime recharge' : 'Monthly recharge',
                      totalRechargeValue: _selectedTab == 0 ? _controller.payload.lifetimeRechargeCoinExp : _controller.payload.monthlyRechargeCoinExp,
                    ),
                    const SizedBox(height: 14),
                    _ThresholdTable(progress: progress),
                    const SizedBox(height: 14),
                    _RuleNote(isVip: _selectedTab == 0),
                  ],
                ),
    );
  }
}

class _VipSwitchTabs extends StatelessWidget {
  const _VipSwitchTabs({required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFEDE3D7))),
      child: Row(
        children: [
          _TabButton(label: 'VIP Center', selected: selectedIndex == 0, onTap: () => onChanged(0)),
          _TabButton(label: 'SVIP Center', selected: selectedIndex == 1, onTap: () => onChanged(1)),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF251538) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: selected ? Colors.white : const Color(0xFF7B6A86), fontWeight: FontWeight.w900, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class _VipHeroCard extends StatelessWidget {
  const _VipHeroCard({required this.progress});

  final VipProgress progress;

  @override
  Widget build(BuildContext context) {
    final isVip = progress.track == 'vip';
    final title = isVip ? 'VIP ${progress.level}' : 'SVIP ${progress.level}';
    final subtitle = isVip ? 'Lifetime recharge based status' : 'Monthly recharge based temporary status';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isVip ? const [Color(0xFF251538), Color(0xFFC99A3B)] : const [Color(0xFF251538), Color(0xFF6D5DF6)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.16), blurRadius: 22, offset: const Offset(0, 12))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(18)),
            child: Icon(isVip ? Icons.workspace_premium_rounded : Icons.diamond_rounded, color: const Color(0xFFFFD166), size: 30),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.76), fontSize: 12.5, fontWeight: FontWeight.w800)),
          ])),
          Text('${progress.level}/${progress.maxLevel}', style: const TextStyle(color: Color(0xFFFFD166), fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.isMaxLevel ? 1 : progress.progress,
            minHeight: 10,
            backgroundColor: Colors.white.withValues(alpha: 0.14),
            color: const Color(0xFF12C7B7),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          progress.isMaxLevel ? 'Max level reached' : '${compactCoins(progress.expIntoLevel)} / ${compactCoins(progress.expNeededForNextLevel)} coins toward next level',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ]),
    );
  }
}

class _VipMetricCard extends StatelessWidget {
  const _VipMetricCard({required this.progress, required this.totalRechargeLabel, required this.totalRechargeValue});

  final VipProgress progress;
  final String totalRechargeLabel;
  final int totalRechargeValue;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Synced level values',
      children: [
        _MetricRow(label: totalRechargeLabel, value: '${compactCoins(totalRechargeValue)} coins'),
        _MetricRow(label: 'Current level', value: 'Lv ${progress.level}'),
        _MetricRow(label: 'Next level threshold', value: progress.isMaxLevel ? 'Max level' : '${compactCoins(progress.nextLevelExp)} coins'),
        _MetricRow(label: 'Next level rupee value', value: progress.isMaxLevel ? 'Max level' : compactRupees((progress.thresholds.where((item) => item.level == progress.level + 1).firstOrNull?.requiredRupeeValue) ?? 0)),
        _MetricRow(label: 'Max threshold', value: '${compactCoins(progress.maxTotalExp)} coins'),
        _MetricRow(label: 'Max rupee value', value: compactRupees(progress.maxRupeeValue)),
        _MetricRow(label: 'Source', value: progress.curveType),
      ],
    );
  }
}

class _ThresholdTable extends StatelessWidget {
  const _ThresholdTable({required this.progress});

  final VipProgress progress;

  @override
  Widget build(BuildContext context) {
    final thresholds = progress.thresholds;
    return _SectionCard(
      title: '${progress.label} thresholds',
      children: [
        if (thresholds.isEmpty)
          const Text('No thresholds received from backend.', style: TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w800))
        else
          for (final threshold in thresholds)
            _ThresholdRow(threshold: threshold, currentLevel: progress.level),
      ],
    );
  }
}

class _ThresholdRow extends StatelessWidget {
  const _ThresholdRow({required this.threshold, required this.currentLevel});

  final VipLevelThreshold threshold;
  final int currentLevel;

  @override
  Widget build(BuildContext context) {
    final reached = currentLevel >= threshold.level;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: reached ? const Color(0x3312C7B7) : const Color(0xFFFAF7F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: reached ? const Color(0xFF12C7B7) : const Color(0xFFEDE3D7)),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: reached ? const Color(0xFF12C7B7) : const Color(0xFFEDE3D7), shape: BoxShape.circle),
          child: Center(child: Text('${threshold.level}', style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${compactCoins(threshold.requiredCoinRecharge)} coins', style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(compactRupees(threshold.requiredRupeeValue), style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w800)),
        ])),
        Icon(reached ? Icons.check_circle_rounded : Icons.lock_outline_rounded, color: reached ? const Color(0xFF12C7B7) : const Color(0xFF9A8EA4), size: 20),
      ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12.5, fontWeight: FontWeight.w800))),
        Text(value, textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFF251538), fontSize: 13.5, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _RuleNote extends StatelessWidget {
  const _RuleNote({required this.isVip});

  final bool isVip;

  @override
  Widget build(BuildContext context) {
    final text = isVip
        ? 'VIP is lifetime recharge based. It cannot be directly purchased as a standalone product. Values here come from backend VIP threshold table.'
        : 'SVIP is monthly recharge based and temporary. It resets or expires monthly if the required monthly recharge is not met. Values here come from backend SVIP threshold table.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF251538).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(color: Color(0xFF4A2A63), fontSize: 12, height: 1.35, fontWeight: FontWeight.w800)),
    );
  }
}

class _VipErrorState extends StatelessWidget {
  const _VipErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFE84C72), size: 38),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      ),
    );
  }
}
