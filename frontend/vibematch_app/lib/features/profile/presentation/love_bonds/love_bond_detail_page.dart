import 'package:flutter/material.dart';

import 'models/love_bond_models.dart';
import 'widgets/love_bond_task_list.dart';
import 'widgets/love_bonds_background.dart';

class LoveBondDetailPage extends StatelessWidget {
  const LoveBondDetailPage({super.key, required this.bond});

  final LoveBondCardData bond;

  String get _scoreLabel {
    return bond.type == LoveBondType.lover ? 'Affection' : 'Bond Score';
  }

  String get _relationshipLine {
    return switch (bond.type) {
      LoveBondType.lover => 'Love grows with every moment you spend together.',
      LoveBondType.bestie => 'Friendship grows through rooms, Vibes and shared support.',
      LoveBondType.brother => 'Brotherhood grows through support, play and room time.',
      LoveBondType.sister => 'Sisterhood grows through care, Vibes and shared moments.',
    };
  }

  String get _daysLabel {
    return switch (bond.type) {
      LoveBondType.lover => "We're Together",
      LoveBondType.bestie => 'Besties Since',
      LoveBondType.brother => 'Bonded Brothers',
      LoveBondType.sister => 'Sisters Forever',
    };
  }

  int get _daysCount {
    return switch (bond.type) {
      LoveBondType.lover => 1540,
      LoveBondType.bestie => 826,
      LoveBondType.brother => 412,
      LoveBondType.sister => 318,
    };
  }

  int get _scoreValue {
    return switch (bond.type) {
      LoveBondType.lover => 159469,
      LoveBondType.bestie => 88420,
      LoveBondType.brother => 46350,
      LoveBondType.sister => 52180,
    };
  }

  void _showAction(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: bond.primaryColor,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = tasksForBondType(bond.type);
    final progress = (bond.level / 5).clamp(0.0, 1.0);

    return Scaffold(
      body: LoveBondsBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              Row(
                children: [
                  _CircleIconButton(
                    color: bond.primaryColor,
                    icon: Icons.chevron_left_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      '${bond.title} Bond',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: bond.primaryColor, blurRadius: 12),
                          const Shadow(color: Color(0xFF8B3C75), blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                  _GuideButton(
                    color: bond.primaryColor,
                    icon: bond.badgeIcon,
                    onTap: () => _showAction(context, '${bond.title} guide will open.'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _BondHeroPanel(
                bond: bond,
                daysCount: _daysCount,
                daysLabel: _daysLabel,
                scoreLabel: _scoreLabel,
                scoreValue: _scoreValue,
                onPrimaryTap: () => _showAction(context, '${bond.title} management will open.'),
                onScoreTap: () => _showAction(context, '$_scoreLabel history will open.'),
              ),
              const SizedBox(height: 14),
              LoveBondsGlassPanel(
                radius: 28,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [bond.secondaryColor, bond.primaryColor]),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Icon(bond.icon, color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${bond.title} Lv.${bond.level}',
                                style: TextStyle(
                                  color: bond.primaryColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 7),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 9,
                                  backgroundColor: const Color(0xFFEED2E3),
                                  valueColor: AlwaysStoppedAnimation<Color>(bond.primaryColor),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${bond.level * 300} / 1500 $_scoreLabel',
                                style: const TextStyle(
                                  color: Color(0xFF7A617C),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _relationshipLine,
                      style: const TextStyle(
                        color: Color(0xFF6D5570),
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              LoveBondTaskList(
                tasks: tasks,
                onTaskTap: (task) {
                  final suffix = task.capped ? ' Daily cap is enforced by backend later.' : '';
                  _showAction(context, '${task.title} task details will open.$suffix');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BondHeroPanel extends StatelessWidget {
  const _BondHeroPanel({
    required this.bond,
    required this.daysCount,
    required this.daysLabel,
    required this.scoreLabel,
    required this.scoreValue,
    required this.onPrimaryTap,
    required this.onScoreTap,
  });

  final LoveBondCardData bond;
  final int daysCount;
  final String daysLabel;
  final String scoreLabel;
  final int scoreValue;
  final VoidCallback onPrimaryTap;
  final VoidCallback onScoreTap;

  @override
  Widget build(BuildContext context) {
    return LoveBondsGlassPanel(
      radius: 32,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _DaysCounter(days: daysCount, label: daysLabel, color: bond.primaryColor)),
              const SizedBox(width: 12),
              InkWell(
                onTap: onPrimaryTap,
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [bond.primaryColor, bond.secondaryColor]),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.72), width: 1.4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(bond.badgeIcon, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        bond.title,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: 104,
            height: 104,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: bond.primaryColor.withValues(alpha: 0.24), blurRadius: 20)],
            ),
            child: CircleAvatar(
              backgroundColor: bond.primaryColor.withValues(alpha: 0.72),
              child: Text(
                bond.rightAvatarInitial,
                style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            bond.partnerName,
            style: const TextStyle(color: Color(0xFF3C2840), fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            bond.displayName,
            style: const TextStyle(color: Color(0xFF7A617C), fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: onScoreTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: bond.secondaryColor,
                    child: Icon(bond.badgeIcon, color: bond.primaryColor, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$scoreLabel\n$scoreValue',
                      style: const TextStyle(
                        color: Color(0xFF3A2B45),
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFFB58AAA)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaysCounter extends StatelessWidget {
  const _DaysCounter({required this.days, required this.label, required this.color});

  final int days;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: days.toString().split('').map((digit) {
            return Container(
              width: 35,
              height: 44,
              margin: const EdgeInsets.only(right: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                digit,
                style: const TextStyle(color: Color(0xFF241C2A), fontSize: 27, fontWeight: FontWeight.w900),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.68), borderRadius: BorderRadius.circular(14)),
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.color, required this.icon, required this.onTap});

  final Color color;
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
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.72), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 32),
      ),
    );
  }
}

class _GuideButton extends StatelessWidget {
  const _GuideButton({required this.color, required this.icon, required this.onTap});

  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(99)),
        child: Icon(icon, color: color, size: 23),
      ),
    );
  }
}
