import 'package:flutter/material.dart';

import '../../models/family_level_models.dart';
import '../../models/family_ui_models.dart';
import 'family_clan_badge_icon.dart';

class FamilyClanHero extends StatelessWidget {
  const FamilyClanHero({
    super.key,
    required this.profile,
    required this.level,
    required this.exp,
    required this.onBack,
    required this.onInvite,
    required this.onRewards,
    required this.onOptions,
    required this.onLevelTap,
  });

  final FamilyProfileUiModel profile;
  final FamilyLevelProgress level;
  final FamilyExpBreakdown exp;
  final VoidCallback onBack;
  final VoidCallback onInvite;
  final VoidCallback onRewards;
  final VoidCallback onOptions;
  final VoidCallback onLevelTap;

  int get _familyPower => exp.totalExp;

  int get _targetPower {
    if (_familyPower <= 250000) return 250000;
    return ((_familyPower ~/ 250000) + 1) * 250000;
  }

  double get _progress => (_familyPower / _targetPower).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF100A18),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFFFD36A).withValues(alpha: 0.18)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 210,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topRight,
                        radius: 1.25,
                        colors: [Color(0xFF7C3AED), Color(0xFF251538), Color(0xFF0C0712)],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(child: CustomPaint(painter: _ClanPatternPainter())),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Row(
                    children: [
                      _HeroButton(icon: Icons.arrow_back_rounded, onTap: onBack),
                      const Spacer(),
                      _HeroButton(icon: Icons.person_add_alt_1_rounded, onTap: onInvite),
                      const SizedBox(width: 8),
                      _HeroButton(icon: Icons.redeem_rounded, onTap: onRewards),
                      const SizedBox(width: 8),
                      _HeroButton(icon: Icons.more_horiz_rounded, onTap: onOptions),
                    ],
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 72,
                  child: _FamilyAvatarHolder(initial: profile.avatarText),
                ),
                Positioned(
                  left: 118,
                  right: 18,
                  top: 78,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profile.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 24, height: 1.02, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _DarkPill(icon: Icons.tag_rounded, label: profile.id),
                          _DarkPill(icon: Icons.leaderboard_rounded, label: profile.rankLabel),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: -2,
                  child: FamilyClanBadgeIcon(
                    familyName: profile.name,
                    familyLevel: level.tier.label,
                    size: 88,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onLevelTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              decoration: const BoxDecoration(color: Color(0xFF17101F)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD36A).withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: const Color(0xFFFFD36A).withValues(alpha: 0.24)),
                        ),
                        child: const Icon(Icons.military_tech_rounded, color: Color(0xFFFFD36A), size: 24),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Family Level: ${level.tier.label}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text('Gift contribution + active family time', style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFFFFD36A)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(minHeight: 8, value: _progress, backgroundColor: Colors.white.withValues(alpha: 0.10), color: const Color(0xFFFFD36A)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text('${compactFamilyExp(_familyPower)} / ${compactFamilyExp(_targetPower)} power', style: TextStyle(color: Colors.white.withValues(alpha: 0.66), fontSize: 11, fontWeight: FontWeight.w800))),
                      Text('${compactFamilyExp(exp.giftExp)} gift EXP', style: const TextStyle(color: Color(0xFFFFD36A), fontSize: 11, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyAvatarHolder extends StatelessWidget {
  const _FamilyAvatarHolder({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF21112E), Color(0xFFE84C72), Color(0xFFFFD36A)]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20), width: 1.2),
        boxShadow: [BoxShadow(color: const Color(0xFFFFD36A).withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _AvatarPatternPainter())),
          Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900))),
          Positioned(right: 7, bottom: 7, child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Color(0xFFFFD36A), shape: BoxShape.circle), child: const Icon(Icons.groups_rounded, color: Color(0xFF100A18), size: 13))),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.26), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.13))),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }
}

class _DarkPill extends StatelessWidget {
  const _DarkPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: const Color(0xFFFFD36A), size: 13), const SizedBox(width: 4), Text(label, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900))]),
    );
  }
}

class _ClanPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = Colors.white.withValues(alpha: 0.08);
    for (var i = 0; i < 7; i++) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-60 + i * 62, 24 + i * 8, 160, 90), const Radius.circular(34)), stroke);
    }
    final glow = Paint()..color = const Color(0xFFFFD36A).withValues(alpha: 0.13);
    canvas.drawCircle(Offset(size.width * 0.86, size.height * 0.24), 74, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AvatarPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.10)..style = PaintingStyle.stroke..strokeWidth = 1.2;
    canvas.drawCircle(Offset(size.width * 0.28, size.height * 0.28), size.width * 0.45, paint);
    canvas.drawCircle(Offset(size.width * 0.78, size.height * 0.72), size.width * 0.38, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
