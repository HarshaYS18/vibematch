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
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              bond.primaryColor.withValues(alpha: 0.88),
              bond.secondaryColor.withValues(alpha: 0.92),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.78), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: bond.primaryColor.withValues(alpha: 0.16),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _LoveBondCardPatternPainter(color: Colors.white),
                ),
              ),
              Positioned(
                top: 0,
                left: 9,
                right: 9,
                child: Container(
                  height: 27,
                  decoration: BoxDecoration(
                    color: bond.primaryColor.withValues(alpha: 0.82),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(15),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    bond.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.4,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                top: 34,
                bottom: 11,
                left: 4,
                right: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _PartnerAvatar(bond: bond),
                    Text(
                      bond.partnerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.2,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
                      ),
                      child: Text(
                        'Lv.${bond.level}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.8,
                          fontWeight: FontWeight.w900,
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

class _PartnerAvatar extends StatelessWidget {
  const _PartnerAvatar({required this.bond});

  final LoveBondCardData bond;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 45,
      height: 45,
      padding: const EdgeInsets.all(2.2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: bond.primaryColor.withValues(alpha: 0.26), blurRadius: 9),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: bond.primaryColor.withValues(alpha: 0.68),
        child: Text(
          bond.rightAvatarInitial,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
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
    final paint = Paint()..color = color.withValues(alpha: 0.13);
    for (final point in [
      Offset(size.width * 0.15, size.height * 0.28),
      Offset(size.width * 0.77, size.height * 0.42),
      Offset(size.width * 0.22, size.height * 0.78),
      Offset(size.width * 0.86, size.height * 0.82),
    ]) {
      canvas.drawCircle(point, 6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LoveBondCardPatternPainter oldDelegate) => false;
}
