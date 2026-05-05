import 'package:flutter/material.dart';

import 'models/love_bond_models.dart';
import 'widgets/love_bonds_background.dart';

class LoveBondBreakupPage extends StatelessWidget {
  const LoveBondBreakupPage({super.key, required this.bond});

  final LoveBondCardData bond;

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
    return Scaffold(
      body: LoveBondsBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.76),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.chevron_left_rounded, color: bond.primaryColor, size: 32),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Break ${bond.title}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: bond.primaryColor, blurRadius: 12),
                          const Shadow(color: Color(0xFF8B3C75), blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 50),
                ],
              ),
              const SizedBox(height: 24),
              LoveBondsGlassPanel(
                radius: 32,
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: bond.primaryColor.withValues(alpha: 0.24), blurRadius: 18)],
                      ),
                      child: CircleAvatar(
                        backgroundColor: bond.primaryColor.withValues(alpha: 0.70),
                        child: Text(
                          bond.rightAvatarInitial,
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      bond.partnerName,
                      style: const TextStyle(color: Color(0xFF3C2840), fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${bond.title} relationship breakup options',
                      style: const TextStyle(color: Color(0xFF7A617C), fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 18),
                    _BreakupOptionCard(
                      icon: Icons.handshake_rounded,
                      title: 'Mutual Breakup',
                      subtitle: 'Send a breakup request to ${bond.partnerName}. They can accept or reject it.',
                      color: bond.primaryColor,
                      onTap: () => _showAction(context, 'Mutual breakup request will be sent after backend is connected.'),
                    ),
                    const SizedBox(height: 12),
                    _BreakupOptionCard(
                      icon: Icons.bolt_rounded,
                      title: 'Force Breakup',
                      subtitle: 'Break instantly by spending coins. Required coin amount will be decided later.',
                      color: const Color(0xFFE84C72),
                      onTap: () => _showAction(context, 'Force breakup coin cost will be configured later.'),
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

class _BreakupOptionCard extends StatelessWidget {
  const _BreakupOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.84)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(icon, color: color, size: 25),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Color(0xFF3C2840), fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF7A617C), fontSize: 12.5, height: 1.25, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFB58AAA)),
          ],
        ),
      ),
    );
  }
}
