import 'package:flutter/material.dart';

import 'models/love_bond_models.dart';
import 'widgets/love_bond_detail_hero.dart';
import 'widgets/love_bond_level_panel.dart';
import 'widgets/love_bond_task_list.dart';
import 'widgets/love_bonds_background.dart';

class LoveBondDetailPage extends StatelessWidget {
  const LoveBondDetailPage({super.key, required this.bond});

  final LoveBondCardData bond;

  void _showAction(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF8B3C75),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoveBondsBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              Row(
                children: [
                  _CircleIconButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Lover Bond ♡',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 31,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: Color(0xFFFF5AAA), blurRadius: 12),
                          Shadow(color: Color(0xFF8B3C75), blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                  _GuideButton(onTap: () => _showAction(context, 'Bond guide will open.')),
                ],
              ),
              LoveBondDetailHero(
                onCpTap: () => _showAction(context, 'CP management will open.'),
                onAffectionTap: () => _showAction(context, 'Affection history will open.'),
              ),
              LoveBondLevelPanel(
                onRewardsTap: () => _showAction(context, 'Lover rewards and perks will open.'),
              ),
              const SizedBox(height: 14),
              LoveBondTaskList(
                tasks: mockLoverTasks,
                onTaskTap: (task) {
                  final suffix = task.capped ? ' Daily cap is enforced by backend later.' : '';
                  _showAction(context, '${task.title} task details will open.$suffix');
                },
              ),
              const SizedBox(height: 14),
              LoveBondsGlassPanel(
                radius: 26,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: const [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xFFFFCBE6),
                      child: Icon(Icons.favorite_rounded, color: Color(0xFFFF5AAA), size: 30),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Love grows with every moment\nComplete tasks to earn Affection and level up.',
                        style: TextStyle(
                          color: Color(0xFF6D5570),
                          fontSize: 15,
                          height: 1.28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFFE7479C), size: 32),
      ),
    );
  }
}

class _GuideButton extends StatelessWidget {
  const _GuideButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(99),
        ),
        child: const Icon(Icons.favorite_rounded, color: Color(0xFFFF5AAA), size: 23),
      ),
    );
  }
}
