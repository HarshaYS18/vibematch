import 'package:flutter/material.dart';

import '../../models/family_level_models.dart';
import '../../models/family_ui_models.dart';
import 'family_redesign_shared.dart';

class FamilyHeaderCard extends StatelessWidget {
  const FamilyHeaderCard({
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
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: FamilyRedesignDecor.panel(30),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 126,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [FamilyRedesignColors.ink, FamilyRedesignColors.violet, FamilyRedesignColors.coral],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: FamilySoftPatternPainter())),
                Positioned(
                  left: 10,
                  right: 10,
                  top: 10,
                  child: Row(
                    children: [
                      _HeaderIcon(icon: Icons.arrow_back_rounded, onTap: onBack),
                      const Spacer(),
                      _HeaderIcon(icon: Icons.ios_share_rounded, onTap: onShare),
                      const SizedBox(width: 8),
                      _HeaderIcon(icon: Icons.redeem_rounded, onTap: onRewards),
                      const SizedBox(width: 8),
                      _HeaderIcon(icon: Icons.settings_rounded, onTap: onOptions),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -34),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FamilyGradientAvatar(
                        text: profile.avatarText,
                        colors: const [FamilyRedesignColors.ink, FamilyRedesignColors.coral],
                        size: 84,
                        borderRadius: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: FamilyRedesignColors.ink, fontSize: 22, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  FamilySmallPill(icon: Icons.tag_rounded, label: profile.id),
                                  FamilySmallPill(icon: Icons.workspace_premium_rounded, label: profile.minimumVipLabel),
                                  FamilySmallPill(icon: Icons.leaderboard_rounded, label: profile.rankLabel),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: onLevelTap,
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: FamilyRedesignColors.warm, borderRadius: BorderRadius.circular(22)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(gradient: LinearGradient(colors: level.tier.colors), borderRadius: BorderRadius.circular(14)),
                                child: Icon(level.tier.icon, color: Colors.white, size: 23),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${level.tier.label} Family · Lv ${level.level}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: FamilyRedesignColors.ink, fontSize: 14, fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                        Text(level.tier.difficultyLabel, style: const TextStyle(color: FamilyRedesignColors.gold, fontSize: 11, fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(99),
                                      child: LinearProgressIndicator(
                                        minHeight: 7,
                                        value: level.progress,
                                        backgroundColor: const Color(0xFFE8D8CA),
                                        color: level.tier.colors.last,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: FamilyRedesignColors.ink),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${compactFamilyExp(level.expIntoLevel)} / ${compactFamilyExp(level.expNeededForNextLevel)} EXP · quarterly reset',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: FamilyRedesignColors.soft, fontSize: 10.5, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _Stat(label: 'Members', value: '${profile.memberCount}/${profile.maxMembers}', icon: Icons.groups_rounded)),
                      const SizedBox(width: 8),
                      Expanded(child: _Stat(label: 'Gift EXP', value: compactFamilyExp(exp.giftExp), icon: Icons.card_giftcard_rounded)),
                      const SizedBox(width: 8),
                      Expanded(child: _Stat(label: 'Time EXP', value: '${compactFamilyExp(exp.timeExp)}/800', icon: Icons.schedule_rounded)),
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

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.onTap});

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
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.22))),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: FamilyRedesignColors.page, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: FamilyRedesignColors.violet, size: 18),
          const SizedBox(height: 6),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: FamilyRedesignColors.ink, fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: FamilyRedesignColors.soft, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
