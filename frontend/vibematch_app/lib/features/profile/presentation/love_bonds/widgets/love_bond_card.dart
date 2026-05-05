import 'package:flutter/material.dart';

import '../models/love_bond_models.dart';

class LoveBondCard extends StatelessWidget {
  const LoveBondCard({
    super.key,
    required this.bond,
    required this.onTap,
  });

  final LoveBondCardData bond;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 156,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              bond.primaryColor.withValues(alpha: 0.88),
              bond.secondaryColor.withValues(alpha: 0.92),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.78), width: 1.6),
          boxShadow: [
            BoxShadow(
              color: bond.primaryColor.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _LoveBondCardPatternPainter(color: Colors.white),
                ),
              ),
              Positioned(
                top: 0,
                left: 12,
                right: 12,
                child: Container(
                  height: 31,
                  decoration: BoxDecoration(
                    color: bond.primaryColor.withValues(alpha: 0.82),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(17),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    bond.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 36,
                right: 10,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Colors.white, bond.primaryColor.withValues(alpha: 0.86)],
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.white.withValues(alpha: 0.44), blurRadius: 8),
                    ],
                  ),
                  child: Icon(bond.badgeIcon, color: Colors.white, size: 14),
                ),
              ),
              Positioned.fill(
                top: 35,
                child: Column(
                  children: [
                    _PartnerAvatar(bond: bond),
                    const SizedBox(height: 6),
                    Text(
                      bond.partnerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.2,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 5)],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
                      ),
                      child: Text(
                        'Lv.${bond.level}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      bond.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
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

class _PartnerAvatar extends StatelessWidget {
  const _PartnerAvatar({required this.bond});

  final LoveBondCardData bond;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(2.6),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: bond.primaryColor.withValues(alpha: 0.30), blurRadius: 12),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: bond.primaryColor.withValues(alpha: 0.68),
        child: Text(
          bond.rightAvatarInitial,
          style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _LoveBondCardPatternPainter extends CustomPainter {
  const _LoveBondCardPatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.15);
    for (final point in [
      Offset(size.width * 0.15, size.height * 0.28),
      Offset(size.width * 0.77, size.height * 0.42),
      Offset(size.width * 0.22, size.height * 0.78),
      Offset(size.width * 0.86, size.height * 0.82),
    ]) {
      canvas.drawCircle(point, 7, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LoveBondCardPatternPainter oldDelegate) => false;
}
