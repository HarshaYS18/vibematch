import 'package:flutter/material.dart';

import '../../models/family_ui_models.dart';

class FamilyRedesignColors {
  const FamilyRedesignColors._();

  static const page = Color(0xFFFAF7F1);
  static const warm = Color(0xFFFFF4E8);
  static const ink = Color(0xFF251538);
  static const soft = Color(0xFF7B6A86);
  static const aqua = Color(0xFF12C7B7);
  static const violet = Color(0xFF6D5DF6);
  static const coral = Color(0xFFE84C72);
  static const gold = Color(0xFFC99A3B);
  static const neon = Color(0xFF63FF2E);
  static const line = Color(0xFFECE2D8);
}

class FamilyRedesignDecor {
  const FamilyRedesignDecor._();

  static BoxDecoration panel(double radius) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: FamilyRedesignColors.line),
      boxShadow: [
        BoxShadow(
          color: FamilyRedesignColors.ink.withValues(alpha: 0.055),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

class FamilyGradientAvatar extends StatelessWidget {
  const FamilyGradientAvatar({super.key, required this.text, required this.colors, required this.size, this.borderRadius});

  final String text;
  final List<Color> colors;
  final double size;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: borderRadius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: borderRadius == null ? null : BorderRadius.circular(borderRadius!),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
      ),
      child: Center(
        child: Text(text, style: TextStyle(color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class FamilySmallPill extends StatelessWidget {
  const FamilySmallPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: FamilyRedesignColors.page, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: FamilyRedesignColors.violet, size: 13),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: FamilyRedesignColors.soft, fontSize: 10.5, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class FamilyRoleChip extends StatelessWidget {
  const FamilyRoleChip({super.key, required this.role});

  final FamilyRole role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      FamilyRole.owner => FamilyRedesignColors.gold,
      FamilyRole.admin => FamilyRedesignColors.violet,
      FamilyRole.member => FamilyRedesignColors.aqua,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Text(role.label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w900)),
    );
  }
}

class FamilyPrimaryButton extends StatelessWidget {
  const FamilyPrimaryButton({super.key, required this.label, required this.onTap, this.danger = false});

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: danger ? FamilyRedesignColors.coral : FamilyRedesignColors.ink,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
      ),
    );
  }
}

class FamilySecondaryButton extends StatelessWidget {
  const FamilySecondaryButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 50,
        decoration: BoxDecoration(color: FamilyRedesignColors.page, borderRadius: BorderRadius.circular(18)),
        child: Center(child: Text(label, style: const TextStyle(color: FamilyRedesignColors.ink, fontWeight: FontWeight.w900))),
      ),
    );
  }
}

class FamilySheetShell extends StatelessWidget {
  const FamilySheetShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 14),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

class FamilySoftPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bubblePaint = Paint()..color = Colors.white.withValues(alpha: 0.10);
    for (var i = 0; i < 7; i++) {
      canvas.drawCircle(Offset(size.width * (i / 6), size.height * 0.25), 42 + i * 4, bubblePaint);
    }

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 2;
    for (var i = 0; i < 9; i++) {
      canvas.drawLine(Offset(i * size.width / 8, 0), Offset(size.width - i * 18, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
