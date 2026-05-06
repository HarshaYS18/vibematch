import 'package:flutter/material.dart';

import 'widgets/profile_match_score_badge.dart';

class PublicProfilePage extends StatelessWidget {
  const PublicProfilePage({
    super.key,
    this.userId = '6418000000',
    this.displayName = 'Vibe User',
    this.username,
  });

  final String userId;
  final String displayName;
  final String? username;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.trim().isEmpty ? 'V' : displayName.trim()[0].toUpperCase();
    final score = _mockMatchScore(userId);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: const Color(0xFFECE2D8)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF251538).withValues(alpha: 0.08),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 164,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF251538), Color(0xFF6D5DF6), Color(0xFFE84C72)],
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              left: 14,
                              top: 14,
                              child: _HeaderButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
                            ),
                            Positioned(
                              right: 14,
                              top: 14,
                              child: _HeaderButton(icon: Icons.ios_share_rounded, onTap: () => _toast(context, 'Profile share sheet will open.')),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 18,
                        bottom: -54,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 9))],
                          ),
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: const Color(0xFF6D5DF6),
                            child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ),
                      Positioned(right: 16, bottom: -42, child: ProfileMatchScoreBadge(score: score, compact: true)),
                    ],
                  ),
                  const SizedBox(height: 62),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
                        const SizedBox(height: 6),
                        Text(username == null ? 'ID $userId' : '@$username · ID $userId', style: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 13, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        const Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Badge(icon: Icons.diamond_rounded, label: 'VIP 18', color: Color(0xFFE84C72)),
                            _Badge(icon: Icons.auto_awesome_rounded, label: 'SVIP 3', color: Color(0xFF6D5DF6)),
                            _Badge(icon: Icons.family_restroom_rounded, label: 'Moon Fam Lv.12', color: Color(0xFF12C7B7)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Building premium live rooms, Vibes, gifts, games and a trusted social-audio community.',
                          style: TextStyle(color: Color(0xFF4A2A63), fontSize: 13, fontWeight: FontWeight.w700, height: 1.35),
                        ),
                        const SizedBox(height: 14),
                        const Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            _InterestChip('Music Rooms'),
                            _InterestChip('Gaming'),
                            _InterestChip('Tech'),
                            _InterestChip('Fitness'),
                            _InterestChip('Live Audio'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _MainButton(label: 'Follow', icon: Icons.person_add_alt_1_rounded, filled: true, onTap: () => _toast(context, 'Follow state updated locally.'))),
                            const SizedBox(width: 10),
                            Expanded(child: _MainButton(label: 'Message', icon: Icons.chat_bubble_rounded, filled: false, onTap: () => _toast(context, 'Message request will open.'))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _mockMatchScore(String value) {
    final numeric = int.tryParse(value.replaceAll(RegExp('[^0-9]'), '')) ?? 72;
    return 55 + (numeric % 41);
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538)));
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: const Color(0xFF251538))),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 14), const SizedBox(width: 4), Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900))]),
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Text(label, style: const TextStyle(color: Color(0xFF5F526B), fontSize: 11.5, fontWeight: FontWeight.w900)),
    );
  }
}

class _MainButton extends StatelessWidget {
  const _MainButton({required this.label, required this.icon, required this.filled, required this.onTap});
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 48,
        decoration: BoxDecoration(color: filled ? const Color(0xFF251538) : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF251538))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: filled ? Colors.white : const Color(0xFF251538), size: 18), const SizedBox(width: 7), Text(label, style: TextStyle(color: filled ? Colors.white : const Color(0xFF251538), fontWeight: FontWeight.w900))]),
      ),
    );
  }
}
