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
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 270,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              bond.primaryColor.withValues(alpha: 0.86),
              bond.secondaryColor.withValues(alpha: 0.88),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.76), width: 2),
          boxShadow: [
            BoxShadow(
              color: bond.primaryColor.withValues(alpha: 0.23),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _LoveBondCardPatternPainter(color: Colors.white),
                ),
              ),
              Positioned(
                top: 0,
                left: 30,
                right: 30,
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: bond.primaryColor.withValues(alpha: 0.84),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(22),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    bond.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 50,
                right: 16,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Colors.white, bond.primaryColor.withValues(alpha: 0.88)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.48),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Icon(bond.badgeIcon, color: Colors.white, size: 20),
                ),
              ),
              Positioned.fill(
                top: 60,
                child: Column(
                  children: [
                    _BondIconStage(bond: bond),
                    const SizedBox(height: 5),
                    Text(
                      'Lv.${bond.level}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 6)],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _BondAvatarLink(bond: bond),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        bond.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                          shadows: [Shadow(color: Colors.black26, blurRadius: 7)],
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

class _BondIconStage extends StatelessWidget {
  const _BondIconStage({required this.bond});

  final LoveBondCardData bond;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.28),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.36),
            blurRadius: 22,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          bond.icon,
          color: Colors.white,
          size: 42,
          shadows: [
            Shadow(color: bond.primaryColor.withValues(alpha: 0.55), blurRadius: 12),
          ],
        ),
      ),
    );
  }
}

class _BondAvatarLink extends StatelessWidget {
  const _BondAvatarLink({required this.bond});

  final LoveBondCardData bond;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(left: 0, child: _BondAvatar(initial: bond.leftAvatarInitial, color: bond.primaryColor)),
          Positioned(right: 0, child: _BondAvatar(initial: bond.rightAvatarInitial, color: bond.primaryColor)),
          Container(
            width: 40,
            height: 27,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [bond.primaryColor, bond.secondaryColor]),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

class _BondAvatar extends StatelessWidget {
  const _BondAvatar({required this.initial, required this.color});

  final String initial;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 2.4),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.26), blurRadius: 10)],
      ),
      child: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.68),
        child: Text(
          initial,
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
    final paint = Paint()..color = color.withValues(alpha: 0.16);
    for (final point in [
      Offset(size.width * 0.15, size.height * 0.24),
      Offset(size.width * 0.76, size.height * 0.37),
      Offset(size.width * 0.23, size.height * 0.78),
      Offset(size.width * 0.86, size.height * 0.86),
    ]) {
      canvas.drawCircle(point, 9, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LoveBondCardPatternPainter oldDelegate) => false;
}
