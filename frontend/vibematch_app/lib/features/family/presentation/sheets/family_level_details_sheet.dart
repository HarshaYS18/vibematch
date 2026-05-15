import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/family_api_service.dart';
import '../../models/family_level_models.dart';
import '../widgets/family_redesign_shared.dart';

class FamilyLevelDetailsSheet extends StatefulWidget {
  const FamilyLevelDetailsSheet({super.key, required this.level, required this.exp});

  final FamilyLevelProgress level;
  final FamilyExpBreakdown exp;

  @override
  State<FamilyLevelDetailsSheet> createState() => _FamilyLevelDetailsSheetState();
}

class _FamilyLevelDetailsSheetState extends State<FamilyLevelDetailsSheet> {
  static const FamilyApiService _api = FamilyApiService();

  FamilyExpConfig? _config;
  bool _loadingConfig = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadConfig());
  }

  Future<void> _loadConfig() async {
    setState(() => _loadingConfig = true);
    try {
      final config = await _api.getExpConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _loadingConfig = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingConfig = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.level;
    final exp = widget.exp;
    final rules = _config?.raw ?? const <String, dynamic>{};
    final backendGiftRule = _ruleValue(rules, const ['gift_exp_per_coin', 'gift_coin_exp_rate', 'gift_rule']);
    final backendTimeRule = _ruleValue(rules, const ['time_exp_per_minute', 'room_time_exp_per_minute', 'time_rule']);
    final backendQuarterRule = _ruleValue(rules, const ['quarter_reset_rule', 'reset_rule', 'quarterly_reset']);

    return FamilySheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(gradient: LinearGradient(colors: level.tier.colors), borderRadius: BorderRadius.circular(18)),
                child: Icon(level.tier.icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${level.tier.label} Family · Lv ${level.level}',
                  style: const TextStyle(color: FamilyRedesignColors.ink, fontSize: 21, fontWeight: FontWeight.w900),
                ),
              ),
              if (_loadingConfig)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: FamilyRedesignColors.gold),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(minHeight: 10, value: level.progress, backgroundColor: const Color(0xFFE8D8CA), color: level.tier.colors.last),
          ),
          const SizedBox(height: 8),
          Text('${compactFamilyExp(level.expIntoLevel)} / ${compactFamilyExp(level.expNeededForNextLevel)} EXP to next level', style: const TextStyle(color: FamilyRedesignColors.soft, fontSize: 12.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          _RuleTile(icon: Icons.card_giftcard_rounded, title: 'Gift EXP', body: backendGiftRule ?? exp.rules.giftRuleLabel),
          _RuleTile(icon: Icons.schedule_rounded, title: 'Time EXP', body: backendTimeRule ?? exp.rules.timeRuleLabel),
          _InfoLine(title: 'Gift contribution', value: '${compactFamilyExp(exp.giftCoinsSpent)} coins → ${compactFamilyExp(exp.giftExp)} EXP'),
          _InfoLine(title: 'Time contribution', value: '${compactFamilyExp(exp.timeMinutes)} min → ${compactFamilyExp(exp.timeExp)} EXP'),
          _InfoLine(title: 'Member capacity', value: '${level.maxMembers} members'),
          _InfoLine(title: 'Admin capacity', value: '${level.adminCapacity} admins'),
          if (level.minimumVipLabel != null) _InfoLine(title: 'Minimum join requirement', value: level.minimumVipLabel!),
          _RuleTile(
            icon: Icons.restart_alt_rounded,
            title: 'Quarterly reset',
            body: backendQuarterRule ?? 'Family level and ranking reset quarterly. Backend should keep historical quarter records.',
          ),
          if (_config != null)
            const _RuleTile(
              icon: Icons.cloud_done_rounded,
              title: 'Backend config',
              body: 'Family EXP rules are loaded from GET /families/config/exp.',
            ),
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: FamilyRedesignColors.page, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: FamilyRedesignColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: FamilyRedesignColors.ink, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(body, style: const TextStyle(color: FamilyRedesignColors.soft, height: 1.3, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(color: FamilyRedesignColors.soft, fontWeight: FontWeight.w800))),
          Text(value, style: const TextStyle(color: FamilyRedesignColors.ink, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

String? _ruleValue(Map<String, dynamic> rules, List<String> keys) {
  for (final key in keys) {
    final value = rules[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}
