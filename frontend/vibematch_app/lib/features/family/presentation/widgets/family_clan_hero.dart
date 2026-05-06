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
    required this.onShare,
    required this.onRewards,
    required this.onOptions,
    required this.onLevelTap,
  });

  final FamilyProfileUiModel profile;
  final FamilyLevelProgress level;
  final FamilyExpBreakdown exp;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onRewards;
  final VoidCallback onOptions;
  final VoidCallback onLevelTap;

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
            height: 196,
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
                      _HeroButton(icon: Icons.ios_share_rounded, onTap: onShare),
                      const SizedBox(width: 8),
                      _HeroButton(icon: Icons.redeem_rounded, onTap: onRewards),
                      const SizedBox(width: 8),
                      _HeroButton(icon: Icons.more_horiz_rounded, onTap: onOptions),
                    ],
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 12,
                  child: FamilyClanBadgeIcon(
                    familyName: profile.name,
                    familyLevel: level.tier.label,
                    size: 112,
                  ),
                ),
                Positioned(
                  left: 132,
                  right: 18,
                  bottom: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(profile.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _DarkPill(icon: Icons.tag_rounded, label: profile.id),
                          _DarkPill(icon: Icons.workspace_premium_rounded, label: profile.minimumVipLabel),
                          _DarkPill(icon: Icons.leaderboard_rounded, label: profile.rankLabel),
                        ],
                      ),
                    ],
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
                        decoration: BoxDecoration(gradient: LinearGradient(colors: level.tier.colors), borderRadius: BorderRadius.circular(15)),
                        child: Icon(level.tier.icon, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${level.tier.label} Family · Lv ${level.level}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text('Season EXP resets quarterly', style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFFFFD36A)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(minHeight: 8, value: level.progress, backgroundColor: Colors.white.withValues(alpha: 0.10), color: const Color(0xFFFFD36A)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text('${compactFamilyExp(level.expIntoLevel)} / ${compactFamilyExp(level.expNeededForNextLevel)} EXP', style: TextStyle(color: Colors.white.withValues(alpha: 0.66), fontSize: 11, fontWeight: FontWeight.w800))),
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
