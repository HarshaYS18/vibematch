import 'package:flutter/material.dart';

class LoveBondDetailHero extends StatelessWidget {
  const LoveBondDetailHero({
    super.key,
    required this.onCpTap,
    required this.onAffectionTap,
  });

  final VoidCallback onCpTap;
  final VoidCallback onAffectionTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 390,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Center(
              child: Container(
                width: 270,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF7DBF).withValues(alpha: 0.16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF7DBF).withValues(alpha: 0.24),
                      blurRadius: 50,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFFF7DBF),
                  size: 210,
                  shadows: [
                    Shadow(color: Colors.white, blurRadius: 28),
                    Shadow(color: Color(0xFFFF5AAA), blurRadius: 18),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    _DayDigit('1'),
                    SizedBox(width: 8),
                    _DayDigit('5'),
                    SizedBox(width: 8),
                    _DayDigit('4'),
                    SizedBox(width: 8),
                    _DayDigit('0'),
                    SizedBox(width: 8),
                    Text(
                      'Day',
                      style: TextStyle(
                        color: Color(0xFF31233F),
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    "We're Together",
                    style: TextStyle(
                      color: Color(0xFF3F3148),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 8,
            top: 92,
            child: InkWell(
              onTap: onCpTap,
              borderRadius: BorderRadius.circular(99),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB65CFF), Color(0xFF55B7FF)],
                  ),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.70), width: 2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'CP',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 4,
            bottom: 44,
            child: SizedBox(
              width: 170,
              height: 70,
              child: Stack(
                alignment: Alignment.center,
                children: const [
                  Positioned(left: 0, child: _HeroAvatar(initial: 'S')),
                  Positioned(right: 0, child: _HeroAvatar(initial: 'R')),
                  _HeroHeartLink(),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 44,
            child: InkWell(
              onTap: onAffectionTap,
              borderRadius: BorderRadius.circular(99),
              child: Container(
                width: 205,
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.70),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0xFFFFCBE6),
                      child: Icon(Icons.favorite_rounded, color: Color(0xFFFF5AAA), size: 22),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Affection Value\n159469',
                        style: TextStyle(
                          color: Color(0xFF3A2B45),
                          fontSize: 15,
                          height: 1.22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Color(0xFFB58AAA)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayDigit extends StatelessWidget {
  const _DayDigit(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 55,
      height: 66,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xFF241C2A),
          fontSize: 42,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HeroAvatar extends StatelessWidget {
  const _HeroAvatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFF5AAA).withValues(alpha: 0.22), blurRadius: 18),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: const Color(0xFFFF9CCB),
        child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _HeroHeartLink extends StatelessWidget {
  const _HeroHeartLink();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 38,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF5AAA), Color(0xFFFFB7DC)]),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
    );
  }
}
