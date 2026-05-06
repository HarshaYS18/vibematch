import 'package:flutter/material.dart';

import '../../models/family_level_models.dart';
import '../widgets/family_redesign_shared.dart';

class FamilyLevelDetailsSheet extends StatelessWidget {
  const FamilyLevelDetailsSheet({super.key, required this.level, required this.exp});

  final FamilyLevelProgress level;
  final FamilyExpBreakdown exp;

  @override
  Widget build(BuildContext context) {
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
          _RuleTile(icon: Icons.card_giftcard_rounded, title: 'Gift EXP', body: exp.rules.giftRuleLabel),
          _RuleTile(icon: Icons.schedule_rounded, title: 'Time EXP', body: exp.rules.timeRuleLabel),
          _InfoLine(title: 'Gift contribution', value: '${compactFamilyExp(exp.giftCoinsSpent)} coins → ${compactFamilyExp(exp.giftExp)} EXP'),
          _InfoLine(title: 'Time contribution', value: '${compactFamilyExp(exp.timeMinutes)} min → ${compactFamilyExp(exp.timeExp)} EXP'),
          _InfoLine(title: 'Member capacity', value: '${level.maxMembers} members'),
          _InfoLine(title: 'Admin capacity', value: '${level.adminCapacity} admins'),
          if (level.minimumVipLabel != null) _InfoLine(title: 'Minimum join requirement', value: level.minimumVipLabel!),
          const _RuleTile(icon: Icons.restart_alt_rounded, title: 'Quarterly reset', body: 'Family level and ranking reset quarterly. Backend should keep historical quarter records.'),
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
