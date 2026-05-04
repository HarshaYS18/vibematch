import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'experience/experience_level_models.dart';
import 'experience/experience_level_pill.dart';

class MiniProfileStatsRow extends StatelessWidget {
  const MiniProfileStatsRow({
    super.key,
    required this.user,
    required this.onVipTap,
    required this.onSentRankingTap,
    required this.onReceivedRankingTap,
  });

  final SeatUser user;
  final VoidCallback onVipTap;
  final VoidCallback onSentRankingTap;
  final VoidCallback onReceivedRankingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MiniProfileVipStatCard(
            vipLevel: user.vipLevel,
            onTap: onVipTap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MiniProfileExperienceStatCard(
            type: ExperienceLevelType.sent,
            level: user.sendingLevel,
            value: compactNumber(user.sentExp),
            onTap: onSentRankingTap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MiniProfileExperienceStatCard(
            type: ExperienceLevelType.received,
            level: user.receivingLevel,
            value: compactNumber(user.receivedExp),
            onTap: onReceivedRankingTap,
          ),
        ),
      ],
    );
  }
}

class MiniProfileVipStatCard extends StatelessWidget {
  const MiniProfileVipStatCard({super.key, required this.vipLevel, required this.onTap});

  final int vipLevel;
  final VoidCallback onTap;

  static const String _assetBase = 'assets/images/vip_badges';

  String get _assetPath {
    if (vipLevel >= 41) return '$_assetBase/vip_purple.png';
    if (vipLevel >= 30) return '$_assetBase/vip_green.png';
    if (vipLevel >= 21) return '$_assetBase/vip_blue.png';
    if (vipLevel >= 11) return '$_assetBase/vip_red.png';
    if (vipLevel >= 6) return '$_assetBase/vip_black_gold.png';
    return '$_assetBase/vip_silver.png';
  }

  Color get _accentColor {
    if (vipLevel >= 41) return const Color(0xFF9C3BCE);
    if (vipLevel >= 30) return const Color(0xFF0F9A5A);
    if (vipLevel >= 21) return const Color(0xFF0C78CF);
    if (vipLevel >= 11) return const Color(0xFFD33B47);
    if (vipLevel >= 6) return const Color(0xFFC99A3B);
    return const Color(0xFF89909A);
  }

  Color get _tintColor {
    if (vipLevel >= 41) return const Color(0xFFF5EBFF);
    if (vipLevel >= 30) return const Color(0xFFE8F8EF);
    if (vipLevel >= 21) return const Color(0xFFEAF4FF);
    if (vipLevel >= 11) return const Color(0xFFFFECEF);
    if (vipLevel >= 6) return const Color(0xFFFFF7E8);
    return const Color(0xFFF2F4F7);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _tintColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accentColor.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: _accentColor.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              const _MiniProfileStatCardShine(),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'VIP Level',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF7B7282),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Center(
                    child: Transform.translate(
                      offset: const Offset(2, 0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              _assetPath,
                              width: 34,
                              height: 34,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.shield_rounded,
                                  color: _accentColor,
                                  size: 31,
                                );
                              },
                            ),
                            const SizedBox(width: 1.5),
                            Text(
                              'VIP $vipLevel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _accentColor,
                                fontSize: 13.8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MiniProfileExperienceStatCard extends StatelessWidget {
  const MiniProfileExperienceStatCard({
    super.key,
    required this.type,
    required this.level,
    required this.value,
    required this.onTap,
  });

  final ExperienceLevelType type;
  final int level;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = experiencePillStyleFor(type: type, level: level);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              style.gradient.first.withValues(alpha: 0.18),
              style.gradient.last.withValues(alpha: 0.14),
              Colors.white.withValues(alpha: 0.84),
            ],
          ),
          border: Border.all(color: style.glowColor.withValues(alpha: 0.26)),
          boxShadow: [
            BoxShadow(
              color: style.glowColor.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              const _MiniProfileStatCardShine(),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExperienceLevelPill(type: type, level: level, compact: true),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: style.gradient.first,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.15,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniProfileStatCardShine extends StatelessWidget {
  const _MiniProfileStatCardShine();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.32),
                  Colors.white.withValues(alpha: 0.11),
                  Colors.white.withValues(alpha: 0.00),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
