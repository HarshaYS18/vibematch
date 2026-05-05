import 'package:flutter/material.dart';

import 'love_bond_detail_page.dart';
import 'models/love_bond_models.dart';
import 'widgets/love_bond_card.dart';
import 'widgets/love_bonds_background.dart';

class LoveBondsPage extends StatelessWidget {
  const LoveBondsPage({super.key});

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

  void _openBond(BuildContext context, LoveBondCardData bond) {
    if (bond.type == LoveBondType.lover) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LoveBondDetailPage(bond: bond)),
      );
      return;
    }

    _showAction(context, '${bond.title} bond detail will use the same pattern as Lover Bond.');
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
                  const Spacer(),
                  _GuideButton(onTap: () => _showAction(context, 'Love & Bonds guide will open.')),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Love & Bonds',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  shadows: [
                    Shadow(color: Color(0xFFFF5AAA), blurRadius: 14),
                    Shadow(color: Color(0xFF8B3C75), blurRadius: 3),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '✦ Collect and cherish every special bond ✦',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Color(0xFF8B3C75), blurRadius: 6)],
                ),
              ),
              const SizedBox(height: 26),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: mockLoveBondCards.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 14,
                  mainAxisExtent: 300,
                ),
                itemBuilder: (context, index) {
                  final bond = mockLoveBondCards[index];
                  return LoveBondCard(
                    bond: bond,
                    onTap: () => _openBond(context, bond),
                  );
                },
              ),
              const SizedBox(height: 18),
              LoveBondsGlassPanel(
                radius: 24,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: const [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0xFFFFCBE6),
                      child: Icon(Icons.favorite_rounded, color: Color(0xFFFF5AAA)),
                    ),
                    SizedBox(width: 14),
                    Expanded(child: _BondSummary(title: 'Total Bonds', value: '4')),
                    SizedBox(width: 8),
                    Expanded(child: _BondSummary(title: 'Total Level', value: '7')),
                    SizedBox(width: 8),
                    Expanded(child: _BondSummary(title: 'Affection', value: '159469')),
                    Icon(Icons.chevron_right_rounded, color: Color(0xFF8B3C75)),
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
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFFE7479C), size: 34),
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
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(99),
        ),
        child: const Row(
          children: [
            Icon(Icons.favorite_rounded, color: Color(0xFFFF5AAA), size: 20),
            SizedBox(width: 5),
            Text('Guide', style: TextStyle(color: Color(0xFFE7479C), fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _BondSummary extends StatelessWidget {
  const _BondSummary({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Color(0xFF8B6C91), fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(color: Color(0xFF5C2B60), fontSize: 18, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
